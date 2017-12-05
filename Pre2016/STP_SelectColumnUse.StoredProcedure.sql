CREATE PROCEDURE [dbo].[STP_SelectColumnUse] 
	@SchemaName NVARCHAR(128), 
	@TableName NVARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql NVARCHAR(MAX) = ''

	SELECT @sql = CASE WHEN @sql = '' THEN 'SELECT SUM(CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 0 ELSE 1 END) AS [' + COLUMN_NAME + ']' ELSE @sql + ' , SUM(CASE WHEN [' + COLUMN_NAME + '] IS NULL THEN 0 ELSE 1 END) AS [' + COLUMN_NAME + ']' END
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @TableName

	SET @sql = @sql + ' FROM [' + @SchemaName + '].[' + @TableName + ']'

	EXEC sp_executesql @sql
END
