 CREATE PROCEDURE versioning.STP_VersioningTransfer_Complete
 (
	@VersioningTransferID BIGINT
 )
 AS
 BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRANSACTION

	BEGIN TRY

		IF @VersioningTransferID IS NULL
		BEGIN
			DECLARE @LocalErrorMessage NVARCHAR(200) 
			SET @LocalErrorMessage = 'VersioningTransferID is not allowed as NULL' 
			RAISERROR(@LocalErrorMessage,16,1)
		END
		
		UPDATE versioning.VersioningTransfer
		SET VersioningID_Transfered_Timestamp = GETUTCDATE()
		WHERE VersioningTransferID = @VersioningTransferID

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

