CREATE SEQUENCE [dbo].[sq_TestSequence] 
 AS [bigint]
 START WITH 1
 INCREMENT BY 1
 MINVALUE -9223372036854775808
 MAXVALUE 9223372036854775807
 CACHE 
GO
CREATE TABLE dbo.tbl_CustomerType
(
	CustomerTypeID BIGINT NOT NULL CONSTRAINT tbl_CustomerType_CustomerTypeID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, tbl_CustomerType_DataHash Binary(32) NOT NULL
	, CustomerTypeName NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerType PRIMARY KEY (CustomerTypeID)
)
GO
CREATE TABLE dbo.tbl_Customer
(
	CustomerID BIGINT NOT NULL CONSTRAINT tbl_Customer_CustomerID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, tbl_Customer_DataHash Binary(32) NOT NULL
	, CustomerTypeID BIGINT NOT NULL
	, Givenname NVARCHAR(50) NULL
	, Surname NVARCHAR(50) NOT NULL
	, AddressStreetname NVARCHAR(50) NULL
	, AddressePostalcode NVARCHAR(50) NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_Customer PRIMARY KEY (CustomerID)
)
GO
ALTER TABLE dbo.tbl_Customer
ADD CONSTRAINT FK_Customer_CustomerTypeID
FOREIGN KEY (CustomerTypeID) REFERENCES tbl_CustomerType(CustomerTypeID); 
GO
CREATE TABLE dbo.tbl_CustomerOrder
(
	CustomerOrderID BIGINT NOT NULL CONSTRAINT tbl_CustomerOrder_CustomerOrderID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, tbl_CustomerOrder_DataHash Binary(32) NOT NULL
	, CustomerID BIGINT NULL
	, OrderDate DATETIME2 NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrder PRIMARY KEY (CustomerOrderID)
)
GO
ALTER TABLE dbo.tbl_CustomerOrder
ADD CONSTRAINT FK_CustomerOrder_CustomerID
FOREIGN KEY (CustomerID) REFERENCES tbl_Customer(CustomerID); 
GO
CREATE TABLE dbo.tbl_CustomerOrderLine
(
	CustomerOrderLineID BIGINT NOT NULL CONSTRAINT tbl_CustomerOrderLine_CustomerOrderID_Default DEFAULT (NEXT VALUE FOR dbo.sq_TestSequence)
	, tbl_CustomerOrderLine_DataHash Binary(32) NOT NULL
	, CustomerOrderID BIGINT NULL
	, Amount INT NOT NULL
	, Product NVARCHAR(50) NOT NULL
	, ChangedBy NVARCHAR(50) NULL

    --Primary key definition
    ,CONSTRAINT PK_tbl_CustomerOrderLine PRIMARY KEY (CustomerOrderLineID)
)
GO
ALTER TABLE dbo.tbl_CustomerOrderLine
ADD CONSTRAINT FK_CustomerOrderLine_CustomerOrderID
FOREIGN KEY (CustomerOrderID) REFERENCES tbl_CustomerOrder(CustomerOrderID); 
GO
