CREATE TABLE dbo.tbl_Customer
(
	CustomerID BIGINT NOT NULL CONSTRAINT tbl_Customer_CustomerID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, SHA256 Binary(32) NOT NULL
	, CustomerTypeID BIGINT NOT NULL
	, Givenname NVARCHAR(50) NULL
	, Surname NVARCHAR(50) NOT NULL
	, AddressStreetname NVARCHAR(50) NULL
	, AddressePostalcode NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

   , SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL  
   , SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL  
   , PERIOD FOR SYSTEM_TIME (SysStartTime,SysEndTime)     

    --Primary key definition
    ,CONSTRAINT PK_tbl_Customer PRIMARY KEY (CustomerID)
)
WITH
(
    SYSTEM_VERSIONING = ON 
    (
        HISTORY_TABLE = dbo.tbl_Customer_History
    )
)
GO
CREATE TABLE dbo.tbl_Customer_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_Customer_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_Customer_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerID BIGINT NULL
	, SHA256_Original Binary(32) NOT NULL
	, SHA256_Now Binary(32) NOT NULL
	, CustomerTypeID BIGINT NOT NULL
	, Givenname NVARCHAR(50) NULL
	, Surname NVARCHAR(50) NOT NULL
	, AddressStreetname NVARCHAR(50) NULL
	, AddressePostalcode NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_Customer_Unhandled PRIMARY KEY (UnhandledID)
)
GO
ALTER TABLE dbo.tbl_Customer
ADD CONSTRAINT FK_Customer_CustomerTypeID
FOREIGN KEY (CustomerTypeID) REFERENCES tbl_CustomerType(CustomerTypeID); 
GO
