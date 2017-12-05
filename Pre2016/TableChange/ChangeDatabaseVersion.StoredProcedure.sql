CREATE PROCEDURE dbo.ChangeDatabaseVersion
(
	@NewVersionNumber VARCHAR(100)
)
AS
BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT value FROM fn_listextendedproperty('Version', default, default, default, default, default, default))
	EXEC sp_addextendedproperty 'Version', @NewVersionNumber
	ELSE
	EXEC sp_updateextendedproperty 'Version', @NewVersionNumber

	DECLARE @UpdatedBy VARCHAR(100) = SUSER_NAME() + ' on ' + FORMAT(GETUTCDATE(),'dd-MM-yyyy HH:mm:ss')

	IF NOT EXISTS (SELECT value FROM fn_listextendedproperty('UpdatedBy', default, default, default, default, default, default))
	EXEC sp_addextendedproperty 'UpdatedBy', @UpdatedBy
	ELSE
	EXEC sp_updateextendedproperty 'UpdatedBy', @UpdatedBy

	EXEC dbo.SelectDatabaseVersion

END