CREATE TABLE dbo.tbl_CustomerOrderLine
(
	CustomerOrderLineID BIGINT NOT NULL CONSTRAINT tbl_CustomerOrderLine_CustomerOrderID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, SHA256 Binary(32) NOT NULL
	, CustomerOrderID BIGINT NULL
	, Amount INT NOT NULL
	, Product NVARCHAR(50) NOT NULL
	, ChangedBy NVARCHAR(50) NULL

   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL  
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)     

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrderLine PRIMARY KEY (CustomerOrderLineID)
)
WITH
(
    SYSTEM_VERSIONING = ON 
    (
        HISTORY_TABLE = dbo.tbl_CustomerOrderLine_History
    )
)
GO
CREATE TABLE dbo.tbl_CustomerOrderLine_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_CustomerOrdeLiner_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_CustomerOrderLine_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerOrderLineID BIGINT NULL
	, SHA256_Original Binary(32) NOT NULL
	, SHA256_Now Binary(32) NOT NULL
	, CustomerOrderID BIGINT NULL
	, Amount INT NOT NULL
	, Product NVARCHAR(50) NOT NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrderLine_Unhandled PRIMARY KEY (UnhandledID)
)
GO
ALTER TABLE dbo.tbl_CustomerOrderLine
ADD CONSTRAINT FK_CustomerOrderLine_CustomerOrderID
FOREIGN KEY (CustomerOrderID) REFERENCES tbl_CustomerOrder(CustomerOrderID); 
GO
