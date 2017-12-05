-- =============================================
 -- Author: <Author,,Name>
 -- Create date: <Create Date,,>
 -- Description: <Description,,>
 -- =============================================
 CREATE PROCEDURE <<where>>(.|_)STP_<<what>>
 -- Input Parameters here
 AS
 BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	-- uncomment BEGIN TRANSACTION if transaction is needed
	-- BEGIN TRANSACTION

	BEGIN TRY

		-- Enter code here
		SELECT 'code'

		--When something is wrong in the stored procedure such as expected input parameter is wrong and I want to throw an error I use:
		--DECLARE @ErrorMessage NVARCHAR(200) 
		--SET @ErrorMessage = 'My error text goes here' 
		--RAISERROR(@ErrorMessage,16,1)

		-- uncomment COMMIT TRANSACTION if transaction is needed
		-- COMMIT TRANSACTION

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

