CREATE NONCLUSTERED INDEX [IX_VersioningTransfer_VersioningID_Transfered_Timestamp] ON [versioning].[VersioningTransfer]
(
	VersioningDestination ASC
	, TableName ASC
	, SchemaName ASC
	, VersioningID_Transfered_Timestamp DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
