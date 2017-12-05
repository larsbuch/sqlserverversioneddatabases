CREATE NONCLUSTERED INDEX [IX_VersioningTransfer_VersioningDestination_TableName] ON [versioning].[VersioningTransfer]
(
	VersioningDestination ASC
	, SchemaName ASC
	, TableName ASC
	, VersioningID_Reserved_End DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
