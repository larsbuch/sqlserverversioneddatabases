 CREATE PROCEDURE versioning.STP_VersioningTransfer_Reserve
(
	@VersioningDestination NVARCHAR(20)
	, @SchemaName SYSNAME
	, @TableName SYSNAME
	, @IsTransferNeeded BIT OUTPUT
	, @VersioningTransferID BIGINT OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRANSACTION

	BEGIN TRY

		IF @VersioningDestination IS NULL OR @SchemaName IS NULL OR @TableName IS NULL
		BEGIN
			DECLARE @LocalErrorMessage NVARCHAR(200) 
			SET @LocalErrorMessage = 'Parameters are not allowed to be NULL' 
			RAISERROR(@LocalErrorMessage,16,1)
		END

		DECLARE @MaxRowsTransfered INT = 8000

		-- Transfer is needed
		SET @IsTransferNeeded = 1

		-- Select unfinished transfered version ID for versioningDestination
		SELECT TOP (1) @VersioningTransferID = VersioningTransferID
		FROM versioning.VersioningTransfer
		WHERE VersioningDestination = @VersioningDestination
		AND SchemaName = @SchemaName
		AND TableName = @TableName
		AND VersioningID_Transfered_Timestamp IS NULL

		-- No partial transfered reserve new transfer
		IF @VersioningTransferID IS NULL
		BEGIN
			DECLARE @LatestCompletedVersioningID BIGINT
			-- Select last transfered version ID for versioningDestination
			SELECT TOP (1) @LatestCompletedVersioningID = VersioningId_Reserved_End
			FROM versioning.VersioningTransfer
			WHERE VersioningDestination = @VersioningDestination
			AND SchemaName = @SchemaName
			AND TableName = @TableName
			ORDER BY VersioningID_Transfered_Timestamp DESC

			SET @LatestCompletedVersioningID = ISNULL(@LatestCompletedVersioningID,0)

			DECLARE @LatestVersioningID BIGINT
			DECLARE @SQL NVARCHAR(2000)

			SET @SQL = 'SELECT @LatestVersioningID = MAX(' + @TableName + '_versioningID) FROM versioning.' + @SchemaName + '_' + @TableName + '_versioning'

			EXECUTE sp_executesql @sql, N'@LatestVersionID BIGINT OUTPUT', @LatestVersioningID = @LatestVersioningID OUTPUT

			SET @LatestVersioningID = ISNULL(@LatestVersioningID,0)

			DECLARE @VersioningID_Start BIGINT
			DECLARE @VersioningID_End BIGINT

			-- Check if update is needed
			IF @LatestCompletedVersioningID < @LatestVersioningID
			BEGIN
				
				IF @LatestVersioningID - @LatestCompletedVersioningID > @MaxRowsTransfered
				BEGIN
					-- over @MaxRowsTransfered so limit to that amount
					SET @VersioningID_Start = @LatestCompletedVersioningID + 1
					SET @VersioningID_End = @LatestCompletedVersioningID + @MaxRowsTransfered
				END
				ELSE
				BEGIN
					-- over @MaxRowsTransfered so limit to that amount
					SET @VersioningID_Start = @LatestCompletedVersioningID + 1
					SET @VersioningID_End = @LatestCompletedVersioningID + @MaxRowsTransfered
				END

				-- Get new VersioningTransferID
				SET @VersioningTransferID = (NEXT VALUE FOR [versioning].[VersioningTransferID_Sequence])

				-- Insert new VersioningTransfer
				INSERT INTO [versioning].[VersioningTransfer]
						   ([VersioningTransferID]
						   ,[VersioningDestination]
						   ,[SchemaName]
						   ,[TableName]
						   ,[VersioningID_Reserved_Start]
						   ,[VersioningID_Reserved_End])
					 VALUES
						   (@VersioningTransferID
						   ,@VersioningDestination
						   ,@SchemaName
						   ,@TableName
						   ,@VersioningID_Start
						   ,@VersioningID_End)

			END -- Transfer is needed
			ELSE
			BEGIN
				-- No transfer is needed
				SET @IsTransferNeeded = 0
			END
		END

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

