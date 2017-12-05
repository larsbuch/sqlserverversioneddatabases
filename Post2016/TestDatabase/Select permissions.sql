WITH RoleMembers (member_principal_id, role_principal_id) 
AS 
(
  SELECT 
   rm1.member_principal_id, 
   rm1.role_principal_id
  FROM sys.database_role_members rm1 (NOLOCK)
   UNION ALL
  SELECT 
   d.member_principal_id, 
   rm.role_principal_id
  FROM sys.database_role_members rm (NOLOCK)
   INNER JOIN RoleMembers AS d 
   ON rm.member_principal_id = d.role_principal_id
)
SELECT member_principal.name AS DatabaseUser
	, role_principals.name AS DatabaseRole
	, CASE 
		WHEN role_principals.name IN ('db_datareader','db_denydatareader') AND database_permissions.permission_name = 'CONNECT' THEN 'BASE READ'
		WHEN role_principals.name IN ('db_datawriter','db_denydatawriter') AND database_permissions.permission_name = 'CONNECT' THEN 'BASE WRITE'
		WHEN database_permissions.permission_name = 'SELECT' THEN 'READ'
		WHEN database_permissions.permission_name IN ('DELETE', 'INSERT','UPDATE') THEN 'WRITE'
		END AS PermissionName
    , CASE 
		WHEN role_principals.name IN ('db_datareader','db_datawriter') AND database_permissions.permission_name = 'CONNECT' THEN 'GRANT'
		WHEN role_principals.name IN ('db_denydatareader','db_denydatawriter') AND database_permissions.permission_name = 'CONNECT' THEN 'DENY'
		ELSE state_desc
		END AS 'State'
	, schemas.name AS 'Schema'
	, objects.name AS 'Object'
FROM RoleMembers
  INNER JOIN sys.database_principals AS role_principals 
	ON (RoleMembers.role_principal_id = role_principals.principal_id)
	AND role_principals.name IN ('db_datareader','db_denydatareader','db_datawriter','db_denydatawriter')
  INNER JOIN sys.database_principals AS member_principal 
	ON (RoleMembers.member_principal_id = member_principal.principal_id)
  LEFT JOIN sys.database_permissions AS database_permissions
	ON role_principals.principal_id = database_permissions.grantee_principal_id
	OR member_principal.principal_id = database_permissions.grantee_principal_id
  LEFT JOIN sys.objects AS objects
    ON database_permissions.major_id = objects.object_id
  LEFT JOIN sys.schemas AS schemas
    ON objects.schema_id = schemas.schema_id
	OR database_permissions.major_id = schemas.schema_id
ORDER BY member_principal.name, CASE WHEN database_permissions.permission_name = 'CONNECT' THEN 1 ELSE 2 END
GO