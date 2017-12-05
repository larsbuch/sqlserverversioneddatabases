CREATE TABLE dbo.tbl_CustomerOrder
(
	CustomerOrderID BIGINT NOT NULL CONSTRAINT tbl_CustomerOrder_CustomerOrderID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, SHA256 Binary(32) NOT NULL
	, CustomerID BIGINT NULL
	, OrderDate DATETIME2 NULL
	, ChangedBy NVARCHAR(50) NULL

   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL  
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)     

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrder PRIMARY KEY (CustomerOrderID)
)
WITH
(
    SYSTEM_VERSIONING = ON 
    (
        HISTORY_TABLE = dbo.tbl_CustomerOrder_History
    )
)
GO
CREATE TABLE dbo.tbl_CustomerOrder_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_CustomerOrder_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_CustomerOrder_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerOrderID BIGINT NULL
	, SHA256_Original Binary(32) NOT NULL
	, SHA256_Now Binary(32) NOT NULL
	, CustomerID BIGINT NULL
	, OrderDate DATETIME2 NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrder_Unhandled PRIMARY KEY (UnhandledID)
)
GO
ALTER TABLE dbo.tbl_CustomerOrder
ADD CONSTRAINT FK_CustomerOrder_CustomerID
FOREIGN KEY (CustomerID) REFERENCES tbl_Customer(CustomerID); 
GO
