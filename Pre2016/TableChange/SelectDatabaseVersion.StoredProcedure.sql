CREATE PROCEDURE dbo.SelectDatabaseVersion
AS
BEGIN
	SET NOCOUNT ON

	SELECT CAST(ISNULL(V.value,'') AS VARCHAR(255)) AS 'Version', CAST(ISNULL(U.value,'') AS VARCHAR(1024)) AS 'UpdatedBy'
						FROM fn_listextendedproperty('Version', default, default, default, default, default, default) V,
						fn_listextendedproperty('UpdatedBy', default, default, default, default, default, default) U
END