# Versioned Databases #

### Where and when to use it ###

* **Client modifiable data:** If you have data that goes to the client/mobile systems where the client should be able to modify the data.
* **Two-way data replication:** Replication of data between systems with one as master.
* Source for simplified change tracking/audit on databases in Sql Server 2012

### Where it is not useful

* Where the performance impact of the INSTEAD OF triggers would make problems. The impact of the triggers is an unmeasured.
* Tables that use identity in primary key eg ```IDENTITY(1,1)``` in definition as it makes the instead of trigger more difficult to make.

### How does it work ###

* **Versioning:** Technically it works by adding one or two shadow tables and adding versioning triggers that track changes on the table in a shadow table for history and possibly save when there are conflicts between the incoming data and the last updated.

* **Structure:**

  * For each table under versioning an historic table will be added (named &lt;original tablename&gt;_historic) that contains the operations done on the table and the time for the operation.

  * If conflict resolution handling is activated an additional table is added (named &lt;original tablename&gt;_unhandled) which contains conflicting operations that need to be handled.

  * Each table needs to have a column for tracking the data changes version. It is a SHA256 hash (``` BINARY(32)```) over the non-key column-names and column data here called a datahash.

    Datahash column is named &lt;tablename&gt;_DataHash fx ```tbl_Customer_DataHash``` 

  * To each table an INSTEAD OF trigger is added for each insert, update and delete

* **Example Structure:** The example tables consist of **tbl_CustomerType**, **tbl_Customer**, **tbl_CustomerOrder** and **tbl_CustomerOrderLine**.

### Revision

0.3.0 Added filtering for non-versioned data

0.2.0 Support for table contents

0.1.0 Initial Commit

### Future changes

* Updating to [Sql Server 2016 System-Versioned Temporal Table](https://docs.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables)
* Adding automatic testing
* Performance impact measuring. I know that the instead of triggers has an impact
* Improving example code
* Support for no master systems
* Support for identity tables if possible.
* Automatic cleanup in history table
* Remove script for versioning tables and triggers

### Who do I talk to? ###

* **Code issues:** Please open an issue and describe how you use the code.
* **Documentation unclear:** Please open an issue and describe it in detail either how you understand what I write.
* **Help needed:**  Please open an issue describing what help is needed and what has been tried.