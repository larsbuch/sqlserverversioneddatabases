CREATE TABLE dbo.tbl_CustomerType
(
	CustomerTypeID BIGINT NOT NULL CONSTRAINT tbl_CustomerType_CustomerTypeID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, SHA256 Binary(32) NOT NULL
	, CustomerTypeName NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL  
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)     

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerType PRIMARY KEY (CustomerTypeID)
)
WITH
(
    SYSTEM_VERSIONING = ON 
    (
        HISTORY_TABLE = dbo.tbl_CustomerType_History
    )
)
GO
CREATE TABLE dbo.tbl_CustomerType_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_CustomerType_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_CustomerType_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerTypeID BIGINT NULL
	, SHA256_Original Binary(32) NOT NULL
	, SHA256_Now Binary(32) NOT NULL
	, CustomerTypeName NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerType_Unhandled PRIMARY KEY (UnhandledID)
)
GO