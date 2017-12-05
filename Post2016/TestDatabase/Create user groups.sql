USE [master]
GO
-- user group [LARS-PC\Database_Owner]
CREATE LOGIN [LARS-PC\Database_Owner] FROM WINDOWS WITH DEFAULT_DATABASE=[Kundehjælp], DEFAULT_LANGUAGE=[us_english]
GO
-- user group [LARS-PC\Database_Access_Denied]
CREATE LOGIN [LARS-PC\Database_Access_Denied] FROM WINDOWS WITH DEFAULT_DATABASE=[Kundehjælp], DEFAULT_LANGUAGE=[us_english]
GO
GRANT IMPERSONATE ON LOGIN::[LARS-PC\Database_Access_Denied] to [Lars-PC\Database_Owner];  
GO 
-- user group [LARS-PC\Database_Read_Only]
CREATE LOGIN [LARS-PC\Database_Read_Only] FROM WINDOWS WITH DEFAULT_DATABASE=[Kundehjælp], DEFAULT_LANGUAGE=[us_english]
GO
GRANT IMPERSONATE ON LOGIN::[LARS-PC\Database_Read_Only] to [Lars-PC\Database_Owner];  
GO 
-- user group [LARS-PC\Database_Write_Access]
CREATE LOGIN [LARS-PC\Database_Write_Access] FROM WINDOWS WITH DEFAULT_DATABASE=[Kundehjælp], DEFAULT_LANGUAGE=[us_english]
GO
GRANT IMPERSONATE ON LOGIN::[LARS-PC\Database_Write_Access] to [Lars-PC\Database_Owner];  
GO 
/* Set up users */
USE Kundehjælp
GO
CREATE USER [Lars-PC\Database_Owner] FOR LOGIN [Lars-PC\Database_Owner]
GO
ALTER ROLE [db_owner] ADD MEMBER [Lars-PC\Database_Owner]
GO
CREATE USER [LARS-PC\Database_Access_Denied] FOR LOGIN [LARS-PC\Database_Access_Denied]
GO
ALTER ROLE [db_datareader] ADD MEMBER [LARS-PC\Database_Access_Denied]
GO
CREATE USER [LARS-PC\Database_Read_Only] FOR LOGIN [LARS-PC\Database_Read_Only]
GO
ALTER ROLE [db_datareader] ADD MEMBER [LARS-PC\Database_Read_Only]
GO
CREATE USER [LARS-PC\Database_Write_Access] FOR LOGIN [LARS-PC\Database_Write_Access]
GO
ALTER ROLE [db_datareader] ADD MEMBER [LARS-PC\Database_Write_Access]
GO
/* Set up specific permissions */
-- user group [LARS-PC\Database_Access_Denied]
DENY SELECT ON [dbo].[tbl_Customer] TO [LARS-PC\Database_Access_Denied]
GO
DENY SELECT ON [dbo].[tbl_Customer_History] TO [LARS-PC\Database_Access_Denied]
GO
DENY SELECT ON [dbo].[tbl_Customer_Unhandled] TO [LARS-PC\Database_Access_Denied]
GO
-- user group [LARS-PC\Database_Write_Access]
GRANT DELETE ON [dbo].[tbl_Customer] TO [LARS-PC\Database_Write_Access]
GO
GRANT INSERT ON [dbo].[tbl_Customer] TO [LARS-PC\Database_Write_Access]
GO
GRANT UPDATE ON [dbo].[tbl_Customer] TO [LARS-PC\Database_Write_Access]
GO
GRANT DELETE ON [dbo].[tbl_Customer_History] TO [LARS-PC\Database_Write_Access]
GO
GRANT INSERT ON [dbo].[tbl_Customer_History] TO [LARS-PC\Database_Write_Access]
GO
GRANT UPDATE ON [dbo].[tbl_Customer_History] TO [LARS-PC\Database_Write_Access]
GO
GRANT DELETE ON [dbo].[tbl_Customer_Unhandled] TO [LARS-PC\Database_Write_Access]
GO
GRANT INSERT ON [dbo].[tbl_Customer_Unhandled] TO [LARS-PC\Database_Write_Access]
GO
GRANT UPDATE ON [dbo].[tbl_Customer_Unhandled] TO [LARS-PC\Database_Write_Access]
GO



