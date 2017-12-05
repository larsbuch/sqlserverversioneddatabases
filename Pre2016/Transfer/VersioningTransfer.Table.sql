CREATE TABLE versioning.VersioningTransfer
(
	VersioningTransferID BIGINT NOT NULL
	, VersioningDestination NVARCHAR(20) NOT NULL
	, SchemaName SYSNAME NOT NULL
	, TableName SYSNAME NOT NULL
	, VersioningID_Reserved_Start BIGINT NOT NULL
	, VersioningID_Reserved_End BIGINT NOT NULL
	, VersioningID_Reserved_Timestamp DATETIME NOT NULL CONSTRAINT DF_VersioningTransfer_VersioningID_Reserved_Timestamp DEFAULT GETUTCDATE()
	, VersioningID_Transfered_Timestamp DATETIME NULL
	, CONSTRAINT PK_VersioningTransfer PRIMARY KEY ([VersioningTransferID] ASC)
)