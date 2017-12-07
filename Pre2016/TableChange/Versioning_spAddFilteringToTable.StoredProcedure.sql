CREATE SCHEMA [versioning]
GO
CREATE PROCEDURE versioning.spAddVersioningToTable(
	@TableName SYSNAME
	, @SchemaName SYSNAME = 'dbo'
	, @HashDataColumnSuffix NVARCHAR(50) = '_DataHash'
	, @HistoryTableSchema SYSNAME = 'NotSet'
	, @HistoryTableSuffix SYSNAME = 'History'
	)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON;

	DECLARE @sql NVARCHAR(MAX)
	DECLARE @sqlColumns NVARCHAR(MAX) = ''
	DECLARE @ErrorText NVARCHAR(1000)

	BEGIN TRANSACTION

	BEGIN TRY

		-- Set @HistoryTableSchema when not set
		IF @HistoryTableSchema = 'NotSet'
		BEGIN
			SET @HistoryTableSchema = @SchemaName
		END

		-- Fail if table has identity
		IF (SELECT TOP 1 OBJECTPROPERTY(tables.object_id,'TableHasIdentity') AS TableHasIdentity
			FROM sys.tables tables
				INNER JOIN sys.schemas AS schemas
					ON tables.schema_id = schemas.schema_id
					AND schemas.name = @SchemaName
					AND tables.name = @TableName) = 1
		BEGIN
			SET @ErrorText = 'Tables that has identity is not supported'
			RAISERROR(@ErrorText,16,1)
			ROLLBACK TRANSACTION
		END

		DECLARE @HistoryTableName SYSNAME

		IF @HistoryTableSchema = @SchemaName
		BEGIN
			IF LEN(@TableName + '_' + @HistoryTableSuffix) > 255
			BEGIN
				SET @ErrorText = 'The combined length of @TableName [' + @TableName + '] and @HistoryTableSuffix [' + @HistoryTableSuffix + '] is longer that 254 char. History table name gets too long.'
				RAISERROR(@ErrorText,16,1)
				ROLLBACK TRANSACTION
			END
			SET @HistoryTableName = @TableName + '_' + @HistoryTableSuffix
		END
		ELSE
		BEGIN
			IF LEN(@HistoryTableName) > 255
			BEGIN
				SET @ErrorText = 'The combined length of @SchemaName [' + @SchemaName + '], @TableName [' + @TableName + '] and @HistoryTableSuffix [' + @HistoryTableSuffix + '] is longer that 254 char. History table name gets too long.'
				RAISERROR(@ErrorText,16,1)
				ROLLBACK TRANSACTION
			END
			SET @HistoryTableName = @HistoryTableName
		END

		DECLARE @HashDataColumn SYSNAME = NULL
		SELECT @HashDataColumn = columns.name
		FROM sys.tables tables
			INNER JOIN sys.columns AS columns 
				ON tables.object_id = columns.object_id
				AND tables.name = @TableName
				AND CHARINDEX(@HashDataColumnSuffix,columns.name) > 0
				AND columns.max_length = 32
				AND columns.is_nullable = 0
			INNER JOIN sys.types AS types 
				ON columns.user_type_id=types.user_type_id
				AND types.name = 'binary'
			INNER JOIN sys.schemas AS schemas
				ON tables.schema_id = schemas.schema_id
				AND schemas.name = @SchemaName

		-- Check base table for DataHash column in @HashDataColumn
		IF @HashDataColumn IS NULL
		BEGIN
			SET @ErrorText = 'Base table does not have DataHash column with suffix: ' + @HashDataColumnSuffix + ' (should have been column of format "[BINARY](32) NOT NULL")'
			RAISERROR(@ErrorText,16,1)
			ROLLBACK TRANSACTION
		END

		-- Get table information
			DECLARE @VersionConfig TABLE(
				[VersionConfigID] [INT] IDENTITY(1,1) NOT NULL,
				[SchemaName] sysname NOT NULL,
				[TableName] sysname NOT NULL,
				[ColumnName] sysname NOT NULL,
				[ColumnOrder] INT NOT NULL,
				[CollationName] sysname NULL,
				[IsNullable] BIT NOT NULL,
				[TypeName] sysname NOT NULL,
				[IsPrimaryKey] BIT NOT NULL,
				[SequencePrimaryKey] [NVARCHAR](2000) NOT NULL
			)

			-- Populate VersionConfig
			insert into @VersionConfig (SchemaName, TableName,ColumnName, ColumnOrder, IsNullable, CollationName, TypeName, IsPrimaryKey, SequencePrimaryKey)
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
				, CASE WHEN OBJECT_DEFINITION(columns.default_object_id) LIKE '%NEXT VALUE%' AND ISNULL(indexes.is_primary_key, 0) = 1 THEN REPLACE(REPLACE(OBJECT_DEFINITION(columns.default_object_id),'(',''),')','') + ' AS ' + columns.name ELSE columns.name END AS SequencePrimaryKey
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

		-- Recreate History Table

		-- Check existance of table
		IF exists (SELECT 0 from sys.tables t join sys.schemas s on t.schema_id = s.schema_id where t.name = @HistoryTableName and s.name = @HistoryTableSchema)
		BEGIN
			DECLARE @FullNewHistoryTable NVARCHAR(300) = '[' + @HistoryTableSchema +'].[' + @HistoryTableName + ']'
			DECLARE @FullOldHistoryTable NVARCHAR(304) = @HistoryTableName + '_Old'

			PRINT '...renaming existing table ' + @FullNewHistoryTable + ' to ' + @FullOldHistoryTable

			-- Drop last old table
			IF exists (SELECT 0 from sys.tables t join sys.schemas s on t.schema_id = s.schema_id where t.name = @FullOldHistoryTable and s.name = @HistoryTableSchema)
			BEGIN
				SET @sql = 'DROP TABLE ' + @FullOldHistoryTable
				EXEC sp_executesql @sql
			END
			-- Drop default constraint as sequence is not needed
			SET @sql = 'ALTER TABLE [' + @HistoryTableName + ']' + CHAR(10)
			SET @sql = @sql + 'DROP CONSTRAINT [' + @HistoryTableName + 'ID_Constraint]' + CHAR(10)
			EXEC sp_executesql @sql
			SET @sql = 'ALTER TABLE [' + @HistoryTableName + ']' + CHAR(10)
			SET @sql = @sql + 'DROP CONSTRAINT [' + @HistoryTableName + '_Time]' + CHAR(10)
			EXEC sp_executesql @sql

			-- Rename primary key
			DECLARE @FullNewHistoryTablePrimaryKey NVARCHAR(300) = '[PK_' + @HistoryTableName + ']'
			DECLARE @FullOldHistoryTablePrimaryKey NVARCHAR(300) = '[PK_' + @HistoryTableName + '_Old]'
			EXEC sp_rename @FullNewHistoryTablePrimaryKey, @FullOldHistoryTablePrimaryKey

			-- Rename to old
			EXEC sp_rename @FullNewHistoryTable, @FullOldHistoryTable;
		END

		-- Check existance of sequence
		IF exists (SELECT * from sys.objects o join sys.schemas s on o.schema_id = s.schema_id where o.type = 'SO' and o.name = @HistoryTableName + 'ID' and s.name = @HistoryTableSchema)
		BEGIN
			SET @sql = 'DROP SEQUENCE [' + @HistoryTableSchema +'].[' + @HistoryTableName + 'ID]' + CHAR(10)
			EXEC sp_executesql @sql
		END

		-- Create sequence
		SET @sql = 'CREATE SEQUENCE [' + @HistoryTableSchema +'].[' + @HistoryTableName + 'ID]' + CHAR(10)
		SET @sql = @sql + ' AS [bigint]' + CHAR(10)
		SET @sql = @sql + ' START WITH 1' + CHAR(10)
		SET @sql = @sql + ' INCREMENT BY 1' + CHAR(10)

		EXEC sp_executesql @sql

		-- Create History table
		SET @sql = 'CREATE TABLE [' + @HistoryTableSchema +'].[' + @HistoryTableName + '] ('  + CHAR(10)
		+ @TableName + '_' + @HistoryTableSuffix + 'ID BIGINT NOT NULL CONSTRAINT [PK_' + @HistoryTableName + '] PRIMARY KEY CONSTRAINT [' + @HistoryTableName + 'ID_Constraint] DEFAULT (NEXT VALUE FOR [' + @HistoryTableSchema +'].[' + @HistoryTableName + 'ID]), ' + CHAR(10)
		+ @HistoryTableSuffix + '_Time DATETIME CONSTRAINT [' + @HistoryTableName + '_Time] DEFAULT GETUTCDATE(), ' + CHAR(10)
		+ 'Operation CHAR(1) NOT NULL, ' + CHAR(10)
		SET @sqlColumns = ''

		SELECT @sqlColumns = @sqlColumns 
					+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
					+ ColumnName + ' ' + TypeName 
					+ CASE WHEN CollationName IS NOT NULL THEN ' COLLATE ' + CollationName + ' ' ELSE '' END
					+ CASE WHEN IsNullable = 1 THEN ' NULL ' ELSE ' NOT NULL ' END + CHAR(10)
		FROM @VersionConfig
		WHERE SchemaName = @SchemaName
		AND TableName = @TableName
		ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns + ')' + CHAR(10)

		EXEC sp_executesql @sql

		IF exists (SELECT 0 from sys.tables t join sys.schemas s on t.schema_id = s.schema_id where t.name = @HistoryTableName + '_Old' and s.name = @HistoryTableSchema)
		BEGIN
			PRINT '...Skipping transfering data to history table as [' + @HistoryTableSchema +'].[' + @HistoryTableName + '_Old] exists' 
		END
		ELSE
		BEGIN
			PRINT '...Transfering data to history table [' + @HistoryTableSchema +'].[' + @HistoryTableName + ']'

			SET @sql = 'INSERT INTO [' + @HistoryTableSchema +'].[' + @HistoryTableName + '] ('  + CHAR(10)
			+ '[Operation] ' + CHAR(10)
			SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ ',[' + ColumnName + '] '
						+ CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

			SET @sql = @sql + @sqlColumns + ')' + CHAR(10)

			SET @sql = @sql + 'SELECT ''i'', ' + CHAR(10)
			SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
						+ '[' + ColumnName + '] '
						+ CASE WHEN CollationName IS NOT NULL THEN ' COLLATE ' + CollationName + ' ' ELSE '' END
						+ CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

			SET @sql = @sql + @sqlColumns + 'FROM [' + @SchemaName +'].[' + @TableName + ']' + CHAR(10)

			EXEC sp_executesql @sql
		END

		PRINT '...Dropping Triggers.'
	
		SET @sql = 'IF OBJECT_ID (''[' + @SchemaName + '].[Trigger_' + @TableName + '_UPDATE_' + @HistoryTableSuffix + ']'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_UPDATE_' + @HistoryTableSuffix + '] END;'
		EXEC sp_executesql @sql
	
		SET @sql = 'IF OBJECT_ID (''[' + @SchemaName + '].[Trigger_' + @TableName + '_INSERT_' + @HistoryTableSuffix + ']'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_INSERT_' + @HistoryTableSuffix + '] END;'
		EXEC sp_executesql @sql
	
		SET @sql = 'IF OBJECT_ID (''[' + @SchemaName + '].[Trigger_' + @TableName + '_DELETE_' + @HistoryTableSuffix + ']'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_DELETE_' + @HistoryTableSuffix + '] END;'
		EXEC sp_executesql @sql
	
		PRINT '...Creating Triggers.'
		-- UPDATE Trigger
		SET @sql = ''
		SET @sql = @sql + 'CREATE TRIGGER [' + @SchemaName + '].[Trigger_' + @TableName + '_UPDATE_' + @HistoryTableSuffix + '] ON [' + @SchemaName + '].[' + @TableName + '] ' + CHAR(10)
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
				FROM @VersionConfig
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
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	)' + CHAR(10) + CHAR(10)

		SET @sql = @sql + '	INSERT @InsertedWithDataHash (' + CHAR(10)
		SET @sql = @sql + @HashDataColumn + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ ', '
						+ ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			ORDER BY ColumnOrder ASC

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	)' + CHAR(10)
		SET @sql = @sql + '	SELECT HASHBYTES(''SHA2_256''' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ CASE WHEN @sqlColumns = '' THEN ', ' ELSE ' + ' END
						+ '''' + ColumnName + ''' + ISNULL(CAST(' + ColumnName + ' AS NVARCHAR(4000)), ''NULL'')' + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			AND IsPrimaryKey = 0
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '		) AS ' + @HashDataColumn + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ ', '
						+ ColumnName  + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	FROM inserted' + CHAR(10) + CHAR(10)

		SET @sql = @sql + '	UPDATE [' + @SchemaName + '].[' + @TableName + ']' + CHAR(10)
		SET @sql = @sql + '	SET ' + @HashDataColumn + ' = inserted.' + @HashDataColumn + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ ', ' + ColumnName + ' = inserted.' + ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	FROM deleted' + CHAR(10)
		SET @sql = @sql + '		INNER JOIN @InsertedWithDataHash AS inserted' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
				+ ' deleted.' + ColumnName + ' = inserted.' + ColumnName + CHAR(10)
			FROM @VersionConfig
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
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND IsPrimaryKey = 1
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns

		-- Insert versioning
		SET @sql = @sql + '	INSERT INTO [' + @HistoryTableSchema +'].[' + @HistoryTableName + ']' + '(' + CHAR(10)
		SET @sql = @sql + '		 Operation' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ ', ' + ColumnName
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	)' + CHAR(10)
		SET @sql = @sql + '	SELECT ''u''' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ ', deleted.' + ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	FROM deleted' + CHAR(10)
		SET @sql = @sql + '		INNER JOIN @InsertedWithDataHash AS inserted' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
				+ ' deleted.' + ColumnName + ' = inserted.' + ColumnName + CHAR(10)
			FROM @VersionConfig
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
		SET @sql = @sql + 'CREATE TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_INSERT_' + @HistoryTableSuffix + '] ON [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
		SET @sql = @sql + 'INSTEAD OF INSERT ' + CHAR(10)
		SET @sql = @sql + 'AS ' + CHAR(10)
		SET @sql = @sql + '	DECLARE @InsertedWithDataHash TABLE (' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
						+ ColumnName + ' ' + TypeName 
						+ CASE WHEN CollationName IS NOT NULL THEN ' COLLATE ' + CollationName + ' ' ELSE '' END + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	)' + CHAR(10)

		SET @sql = @sql + 'INSERT INTO @InsertedWithDataHash (' + CHAR(10)
		SET @sql = @sql + @HashDataColumn + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ ', '
						+ ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			ORDER BY ColumnOrder ASC

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + ')' + CHAR(10)
		SET @sql = @sql + '	SELECT HASHBYTES(''SHA2_256''' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ CASE WHEN @sqlColumns = '' THEN ', ' ELSE ' + ' END
						+ '''' + ColumnName + ''' + ISNULL(CAST(' + ColumnName + ' AS NVARCHAR(4000)), ''NULL'')' + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			AND IsPrimaryKey = 0
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '		) AS ' + @HashDataColumn  + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ ', '
						+ SequencePrimaryKey + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND ColumnName <> @HashDataColumn
			ORDER BY ColumnOrder ASC

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + ' FROM inserted ' + CHAR(10)

		SET @sql = @sql + 'INSERT INTO [' + @SchemaName + '].[' + @TableName + '](' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ CASE WHEN @sqlColumns = '' THEN '' ELSE ', ' END
						+ ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder ASC

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + ')' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns 
						+ CASE WHEN @sqlColumns = '' THEN 'SELECT ' ELSE ', ' END
						+ ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder ASC

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + 'FROM @InsertedWithDataHash ' + CHAR(10) + CHAR(10)

		-- Insert versioning
		SET @sql = @sql + '	INSERT INTO [' + @HistoryTableSchema +'].[' + @HistoryTableName + ']' + '(' + CHAR(10)
		SET @sql = @sql + '		 Operation' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ ', ' + ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	)' + CHAR(10)
		SET @sql = @sql + '	SELECT ''i''' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ ', inserted.' + ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + ' FROM @InsertedWithDataHash AS inserted' + CHAR(10)
		EXEC sp_executesql @sql

		-- DELETE Trigger
		SET @sql = ''
		SET @sql = @sql + 'CREATE TRIGGER [' + @SchemaName +'].[Trigger_' + @TableName + '_DELETE_' + @HistoryTableSuffix + '] ON [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
		SET @sql = @sql + 'INSTEAD OF DELETE ' + CHAR(10)
		SET @sql = @sql + 'AS ' + CHAR(10)

		-- Insert versioning
		SET @sql = @sql + '	INSERT INTO [' + @HistoryTableSchema +'].[' + @HistoryTableName + ']' + '(' + CHAR(10)
		SET @sql = @sql + '		 Operation' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ ', ' + ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	)' + CHAR(10)
		SET @sql = @sql + '	SELECT ''d''' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ ', deleted.' + ColumnName + CHAR(10)
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns
		SET @sql = @sql + '	FROM deleted ' + CHAR(10)
		SET @sql = @sql + '		INNER JOIN [' + @SchemaName +'].[' + @TableName + '] ' + CHAR(10)
		SET @sqlColumns = ''

			SELECT @sqlColumns = @sqlColumns
				+ CASE WHEN @sqlColumns = '' THEN ' ON ' ELSE ' AND ' END
				+ ' deleted.' + ColumnName + ' = [' + @SchemaName +'].[' + @TableName + '].' + ColumnName + CHAR(10)
			FROM @VersionConfig
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
			FROM @VersionConfig
			WHERE SchemaName = @SchemaName
			AND TableName = @TableName
			AND IsPrimaryKey = 1
			ORDER BY ColumnOrder

		SET @sql = @sql + @sqlColumns + CHAR(10) + CHAR(10)
		EXEC sp_executesql @sql

		COMMIT TRANSACTION

	END TRY

	BEGIN CATCH
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ErrorLine INT
		DECLARE @ErrorLineAsText NVARCHAR(10)
		DECLARE @ErrorProcedure NVARCHAR(255)
		DECLARE @ErrorMessage NVARCHAR(4000)

		-- Get error text
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState = ERROR_STATE()
		SET @ErrorLine = ERROR_LINE ()
		SET @ErrorProcedure = OBJECT_NAME(@@PROCID)
		SET @ErrorMessage = ERROR_MESSAGE()

		-- Concatinate errorline and error function if existing
		IF @ErrorLine IS NOT NULL AND @ErrorProcedure IS NOT NULL
		BEGIN
			SET @ErrorLineAsText = CAST(@ErrorLine AS NVARCHAR(10))
			SET @ErrorMessage = 'Procedure/Function: ' + @ErrorProcedure + ' Line: ' + @ErrorLineAsText + ' Message: ' + @ErrorMessage
		END

		-- Test whether the transaction is uncommittable.
		IF (XACT_STATE()) = -1
		BEGIN
			PRINT
			N'The transaction is in an uncommittable state.' +
			'Rolling back transaction.'
			ROLLBACK TRANSACTION;
		END;

		-- Test whether the transaction is committable.
		IF (XACT_STATE()) = 1
		BEGIN
			PRINT
			N'The transaction is committable.' +
			'Committing transaction.'
			COMMIT TRANSACTION;
		END;

		-- Use RAISERROR to make exception that gives detailed message
		-- other message that SqlException to the users of the procedure
		-- and uncomment to log to the application log using WITH LOG
		RAISERROR(@ErrorMessage,@ErrorSeverity, @ErrorState) -- WITH LOG
	END CATCH;
END
GO
