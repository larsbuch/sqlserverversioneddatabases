CREATE PROCEDURE versioning.spAddVersioningToTable(
	@SchemaName sysname
	, @TableName sysname
	, @RepopulateVersionConfig BIT = 1
	, @RecreateTable BIT = 1
	, @HashDataColumn sysname = 'VersioningDataHash'
	, @VersioningTablePostScript NVARCHAR(10) = 'versioning'
	)
AS
	SET NOCOUNT ON

	DECLARE @sql NVARCHAR(MAX)
	DECLARE @sqlColumns NVARCHAR(MAX) = ''

	-- Fail if table has identity
	IF (SELECT TOP 1 OBJECTPROPERTY(tables.object_id,'TableHasIdentity') AS TableHasIdentity
		FROM sys.tables tables
			INNER JOIN sys.schemas AS schemas
				ON tables.schema_id = schemas.schema_id
				AND schemas.name = @SchemaName
				AND tables.name = @TableName) = 1
	BEGIN
		RAISERROR('Tables that has identity is not supported',16,1)
		ROLLBACK TRANSACTION
	END

	-- Check base table for DataHash column in @HashDataColumn
	IF NOT EXISTS(
		SELECT columns.name AS column_name
		FROM sys.tables tables
			INNER JOIN sys.columns AS columns 
				ON tables.object_id = columns.object_id
				AND tables.name = @TableName
				AND columns.name = @HashDataColumn
				AND columns.max_length = 32
				AND columns.is_nullable = 0
			INNER JOIN sys.types AS types 
				ON columns.user_type_id=types.user_type_id
				AND types.name = 'binary'
			INNER JOIN sys.schemas AS schemas
				ON tables.schema_id = schemas.schema_id
				AND schemas.name = @SchemaName
		)
	BEGIN
		DECLARE @ErrorText NVARCHAR(1000) = 'Base table does not have VersioningDataHash column: ' + @HashDataColumn + ' (should have been column of format "[binary](32) NOT NULL")'
		RAISERROR(@ErrorText,16,1)
		ROLLBACK TRANSACTION
	END


	IF @RepopulateVersionConfig = 1
	BEGIN
		-- Create Version config if not existing
		IF NOT EXISTS (SELECT 0 from sys.tables t join sys.schemas s on t.schema_id = s.schema_id where t.name = 'VersionConfig' and s.name = 'versioning')
		BEGIN
			CREATE TABLE [versioning].[VersionConfig](
				[VersionConfigID] [INT] IDENTITY(1,1) NOT NULL,
				[SchemaName] sysname NOT NULL,
				[TableName] sysname NOT NULL,
				[ColumnName] sysname NOT NULL,
				[ColumnOrder] INT NOT NULL,
				[CollationName] sysname NULL,
				[IsNullable] BIT NOT NULL,
				[TypeName] sysname NOT NULL,
				[IsPrimaryKey] BIT NOT NULL,
				[EnableVersioning] [TINYINT] NOT NULL CONSTRAINT [DF_VersionConfig_EnableVersioning]  DEFAULT ((1)),
				[SequencePrimaryKey] [NVARCHAR](2000) NOT NULL
			 CONSTRAINT [PK_AuditConfig] PRIMARY KEY CLUSTERED 
			(
				[VersionConfigID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
			 CONSTRAINT [IX_AuditConfig_UniqueKey] UNIQUE NONCLUSTERED 
			(
				[SchemaName] ASC,
				[TableName] ASC,
				[ColumnName] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY]
		END

		-- Delete from VersionConfig
		DELETE FROM versioning.VersionConfig
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName

		-- Populate VersionConfig
		insert into [versioning].[VersionConfig] (SchemaName, TableName,ColumnName, ColumnOrder, IsNullable, CollationName, TypeName, IsPrimaryKey, EnableVersioning, SequencePrimaryKey)
		SELECT schemas.name AS schema_name
			, tables.name AS table_name
			, columns.name AS column_name
			, columns.column_id AS column_order
			, columns.is_nullable
			, columns.collation_name
			, CASE 
					WHEN types.name IN ('char','varchar','nchar','nvarchar','binary','varbinary') THEN types.name + '(' + CAST(columns.max_length AS NVARCHAR(10)) + ')'
					WHEN types.name IN ('numeric','decimal') THEN types.name + '(' + CAST(columns.precision AS NVARCHAR(10)) + ',' + CAST(columns.scale AS NVARCHAR(10)) + ')'
					ELSE types.name 
				END AS type_name
			, ISNULL(indexes.is_primary_key, 0) AS primary_key
			, CAST(1 AS TINYINT) As EnableVersioning
			, CASE WHEN OBJECT_DEFINITION(columns.default_object_id) LIKE '%NEXT VALUE%' AND ISNULL(indexes.is_primary_key, 0) = 1 THEN REPLACE(REPLACE(OBJECT_DEFINITION(293576084),'(',''),')','') + ' AS ' + columns.name ELSE columns.name END AS SequencePrimaryKey
		FROM sys.tables tables
			INNER JOIN sys.columns AS columns 
				ON tables.object_id = columns.object_id
				AND tables.name = @TableName
			INNER JOIN sys.schemas AS schemas
				ON tables.schema_id = schemas.schema_id
				AND schemas.name = @SchemaName
			INNER JOIN sys.types AS types 
				ON columns.user_type_id=types.user_type_id
			LEFT OUTER JOIN sys.index_columns AS index_columns 
				ON index_columns.object_id = columns.object_id 
				AND index_columns.column_id = columns.column_id
			LEFT OUTER JOIN sys.indexes AS indexes 
				ON index_columns.object_id = indexes.object_id 
				AND index_columns.index_id = indexes.index_id
	END -- @RepopulateVersionConfig = 1

	IF @RecreateTable = 1
	BEGIN
		-- Check existance of table
		IF exists (SELECT 0 from sys.tables t join sys.schemas s on t.schema_id = s.schema_id where t.name = @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript and s.name = @VersioningTablePostScript)
		BEGIN
			SET @sql = 'DROP TABLE [' + @VersioningTablePostScript +'].' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript
			EXEC sp_executesql @sql
		END

		-- Check existance of sequence
		IF exists (SELECT * from sys.objects o join sys.schemas s on o.schema_id = s.schema_id where o.type = 'SO' and o.name = @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + 'ID' and s.name = @VersioningTablePostScript)
		BEGIN
			SET @sql = 'DROP SEQUENCE [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + 'ID]' + CHAR(10)
			EXEC sp_executesql @sql
		END

		-- Create sequence
		SET @sql = 'CREATE SEQUENCE [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + 'ID]' + CHAR(10)
		SET @sql = @sql + ' AS [bigint]' + CHAR(10)
		SET @sql = @sql + ' START WITH 1' + CHAR(10)
		SET @sql = @sql + ' INCREMENT BY 1' + CHAR(10)

		EXEC sp_executesql @sql

		-- Create Audit table
		SET @sql = 'CREATE TABLE [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + '] ('  + CHAR(10)
		+ @TableName + '_' + @VersioningTablePostScript + 'ID BIGINT NOT NULL CONSTRAINT [PK_' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + '] PRIMARY KEY CONSTRAINT [' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + 'ID_Constraint] DEFAULT (NEXT VALUE FOR [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + 'ID]), ' + CHAR(10)
		+ @VersioningTablePostScript + '_Time DATETIME CONSTRAINT ' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + '_Time DEFAULT GETUTCDATE(), ' + CHAR(10)
		+ 'Operation CHAR(1) NOT NULL, ' + CHAR(10)
		SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
					+ ColumnName + ' ' + TypeName 
					+ CASE WHEN CollationName IS NOT NULL THEN ' COLLATE ' + CollationName + ' ' ELSE '' END
					+ CASE WHEN IsNullable = 1 THEN ' NULL ' ELSE ' NOT NULL ' END + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns + ')' + CHAR(10)

		EXEC sp_executesql @sql

	END -- @RecreateTable = 1
	
	PRINT '...Dropping Triggers.'
	
	SET @sql = 'IF OBJECT_ID (''[' + @SchemaName + '].[Trigger_' + @TableName + '_UPDATE_' + @VersioningTablePostScript + ']'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_UPDATE_' + @VersioningTablePostScript + '] END;'
	EXEC sp_executesql @sql
	
	SET @sql = 'IF OBJECT_ID (''[' + @SchemaName + '].[Trigger_' + @TableName + '_INSERT_' + @VersioningTablePostScript + ']'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_INSERT_' + @VersioningTablePostScript + '] END;'
	EXEC sp_executesql @sql
	
	SET @sql = 'IF OBJECT_ID (''[' + @SchemaName + '].[Trigger_' + @TableName + '_DELETE_' + @VersioningTablePostScript + ']'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_DELETE_' + @VersioningTablePostScript + '] END;'
	EXEC sp_executesql @sql
	
	PRINT '...Creating Triggers.'
	-- UPDATE Trigger
	SET @sql = ''
	SET @sql = @sql + 'CREATE TRIGGER [' + @SchemaName + '].[Trigger_' + @TableName + '_UPDATE_' + @VersioningTablePostScript + '] ON [' + @SchemaName + '].[' + @TableName + '] ' + CHAR(10)
	SET @sql = @sql + 'INSTEAD OF UPDATE AS ' + CHAR(10)
	SET @sql = @sql + 'BEGIN ' + CHAR(10)
	SET @sql = @sql + 'SET NOCOUNT ON ' + CHAR(10)
	
	-- Remove option to update Primary Keys and DataHash
	SET @sql = @sql + 'IF ' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ CASE WHEN @sqlColumns = '' THEN '' ELSE ' OR ' END
			+ 'UPDATE(' + ColumnName + ')' + CHAR(10)
		FROM (
			SELECT ColumnName, ColumnOrder
			FROM [versioning].[VersionConfig]
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND IsPrimaryKey = 1
			UNION ALL
			SELECT @HashDataColumn, 8000
			) InnerTable
			ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + 'BEGIN' + CHAR(10)
	SET @sql = @sql + '	RAISERROR(''Updates to primary keys are not allowed'',16,1)' + CHAR(10)
	SET @sql = @sql + '	ROLLBACK TRANSACTION ' + CHAR(10)
	SET @sql = @sql + 'END' + CHAR(10)

	SET @sql = @sql + '	DECLARE @InsertedWithDataHash TABLE (' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
					+ ColumnName + ' ' + TypeName 
					+ CASE WHEN CollationName IS NOT NULL THEN ' COLLATE ' + CollationName + ' ' ELSE '' END + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	)' + CHAR(10) + CHAR(10)

	SET @sql = @sql + '	INSERT @InsertedWithDataHash (' + CHAR(10)
	SET @sql = @sql + @HashDataColumn + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ ', '
					+ ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND EnableVersioning = 1
		ORDER BY ColumnOrder ASC

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	)' + CHAR(10)
	SET @sql = @sql + '	SELECT HASHBYTES(''SHA2_256''' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN ', ' ELSE ' + ' END
					+ '''' + ColumnName + ''' + ISNULL(CAST(' + ColumnName + ' AS NVARCHAR(4000)), ''NULL'')' + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND IsPrimaryKey = 0
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '		) AS ' + @HashDataColumn + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ ', '
					+ ColumnName  + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	FROM inserted' + CHAR(10) + CHAR(10)

	SET @sql = @sql + '	UPDATE [' + @SchemaName + '].[' + @TableName + ']' + CHAR(10)
	SET @sql = @sql + '	SET ' + @HashDataColumn + ' = inserted.' + @HashDataColumn + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ ', ' + ColumnName + ' = inserted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	FROM deleted' + CHAR(10)
	SET @sql = @sql + '		INNER JOIN @InsertedWithDataHash AS inserted' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
			+ ' deleted.' + ColumnName + ' = inserted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND IsPrimaryKey = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '			AND deleted.' + @HashDataColumn + ' <> inserted.' + @HashDataColumn + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ CASE WHEN @sqlColumns = '' THEN ' WHERE ' ELSE ' AND ' END
			+ '['+ @SchemaName + '].[' + TableName + '].[' + ColumnName + '] = inserted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND IsPrimaryKey = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns

	-- Insert versioning
	SET @sql = @sql + '	INSERT INTO [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + ']' + '(' + CHAR(10)
	SET @sql = @sql + '		 Operation' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ ', ' + ColumnName
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	)' + CHAR(10)
	SET @sql = @sql + '	SELECT ''u''' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ ', deleted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	FROM deleted' + CHAR(10)
	SET @sql = @sql + '		INNER JOIN @InsertedWithDataHash AS inserted' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
			+ ' deleted.' + ColumnName + ' = inserted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND IsPrimaryKey = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '			AND deleted.' + @HashDataColumn + ' <> inserted.' + @HashDataColumn + CHAR(10)
	SET @sql = @sql + ' END' + CHAR(10)
	EXEC sp_executesql @sql
	
	-- INSERT Trigger
	SET @sql = ''
	SET @sql = @sql + 'CREATE TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_INSERT_' + @VersioningTablePostScript + '] ON [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
	SET @sql = @sql + 'INSTEAD OF INSERT ' + CHAR(10)
	SET @sql = @sql + 'AS ' + CHAR(10)
	SET @sql = @sql + '	DECLARE @InsertedWithDataHash TABLE (' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
					+ ColumnName + ' ' + TypeName 
					+ CASE WHEN CollationName IS NOT NULL THEN ' COLLATE ' + CollationName + ' ' ELSE '' END + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	)' + CHAR(10)

	SET @sql = @sql + 'INSERT INTO @InsertedWithDataHash (' + CHAR(10)
	SET @sql = @sql + @HashDataColumn + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ ', '
					+ ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND EnableVersioning = 1
		ORDER BY ColumnOrder ASC

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + ')' + CHAR(10)
	SET @sql = @sql + '	SELECT HASHBYTES(''SHA2_256''' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN ', ' ELSE ' + ' END
					+ '''' + ColumnName + ''' + ISNULL(CAST(' + ColumnName + ' AS NVARCHAR(4000)), ''NULL'')' + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND IsPrimaryKey = 0
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '		) AS ' + @HashDataColumn  + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ ', '
					+ SequencePrimaryKey + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND ColumnName <> @HashDataColumn
		AND EnableVersioning = 1
		ORDER BY ColumnOrder ASC

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + ' FROM inserted ' + CHAR(10)

	SET @sql = @sql + 'INSERT INTO [' + @SchemaName + '].[' + @TableName + '](' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
					+ ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder ASC

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + ')' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN 'SELECT ' ELSE ', ' END
					+ ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder ASC

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + 'FROM @InsertedWithDataHash ' + CHAR(10) + CHAR(10)

	-- Insert versioning
	SET @sql = @sql + '	INSERT INTO [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + ']' + '(' + CHAR(10)
	SET @sql = @sql + '		 Operation' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ ', ' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	)' + CHAR(10)
	SET @sql = @sql + '	SELECT ''i''' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ ', inserted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + ' FROM @InsertedWithDataHash AS inserted' + CHAR(10)
	EXEC sp_executesql @sql

	-- DELETE Trigger
	SET @sql = ''
	SET @sql = @sql + 'CREATE TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_DELETE_' + @VersioningTablePostScript + '] ON [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
	SET @sql = @sql + 'INSTEAD OF DELETE ' + CHAR(10)
	SET @sql = @sql + 'AS ' + CHAR(10)

	-- Insert versioning
	SET @sql = @sql + '	INSERT INTO [' + @VersioningTablePostScript +'].[' + @SchemaName + '_' + @TableName + '_' + @VersioningTablePostScript + ']' + '(' + CHAR(10)
	SET @sql = @sql + '		 Operation' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ ', ' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	)' + CHAR(10)
	SET @sql = @sql + '	SELECT ''d''' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ ', deleted.' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND EnableVersioning = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns
	SET @sql = @sql + '	FROM deleted ' + CHAR(10)
	SET @sql = @sql + '		INNER JOIN [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
			+ ' deleted.' + ColumnName + ' = [' + @SchemaName +'].[' + @TableName + '].' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND IsPrimaryKey = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns + CHAR(10) + CHAR(10)

	SET @sql = @sql + '	DELETE [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
	SET @sql = @sql + '	FROM deleted ' + CHAR(10)
	SET @sql = @sql + '		INNER JOIN [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
	SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns
			+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
			+ ' deleted.' + ColumnName + ' = [' + @SchemaName +'].[' + @TableName + '].' + ColumnName + CHAR(10)
		FROM [versioning].[VersionConfig]
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		AND IsPrimaryKey = 1
		ORDER BY ColumnOrder

	SET @sql = @sql + @sqlColumns + CHAR(10) + CHAR(10)
	EXEC sp_executesql @sql
GO
