CREATE SEQUENCE [dbo].[sq_TestSequenceUnhandled] 
 AS [bigint]
 START WITH 1
 INCREMENT BY 1
 MINVALUE -9223372036854775808
 MAXVALUE 9223372036854775807
 CACHE 
GO
CREATE TABLE dbo.tbl_CustomerType_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_CustomerType_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_CustomerType_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerTypeID BIGINT NULL
	, tbl_CustomerType_DataHash_Original Binary(32) NOT NULL
	, tbl_CustomerType_DataHash_Now Binary(32) NOT NULL
	, CustomerTypeName NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerType_Unhandled PRIMARY KEY (UnhandledID)
)
GO
CREATE TABLE dbo.tbl_Customer_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_Customer_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_Customer_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerID BIGINT NULL
	, tbl_Customer_DataHash_Original Binary(32) NOT NULL
	, tbl_Customer_DataHash_Now Binary(32) NOT NULL
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
CREATE TABLE dbo.tbl_CustomerOrder_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_CustomerOrder_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_CustomerOrder_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerOrderID BIGINT NULL
	, tbl_CustomerOrder_DataHash_Original Binary(32) NOT NULL
	, tbl_CustomerOrder_DataHash_New Binary(32) NOT NULL
	, CustomerID BIGINT NULL
	, OrderDate DATETIME2 NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrder_Unhandled PRIMARY KEY (UnhandledID)
)
GO
CREATE TABLE dbo.tbl_CustomerOrderLine_Unhandled
(
	UnhandledID BIGINT CONSTRAINT tbl_CustomerOrdeLiner_Unhandled_UnhandledID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequenceUnhandled)
	, UnhandledTime DATETIME2 NOT NULL CONSTRAINT tbl_CustomerOrderLine_Unhandled_Utc_Now DEFAULT (GETUTCDATE())
	, CustomerOrderLineID BIGINT NULL
	, tbl_CustomerOrderLine_DataHash_Original Binary(32) NOT NULL
	, tbl_CustomerOrderLine_DataHash_New Binary(32) NOT NULL
	, CustomerOrderID BIGINT NULL
	, Amount INT NOT NULL
	, Product NVARCHAR(50) NOT NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrderLine_Unhandled PRIMARY KEY (UnhandledID)
)
GO
