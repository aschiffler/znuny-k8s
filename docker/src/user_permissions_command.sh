APP_USER="znuny"

customLogger "info" "user_permissions" "Set the permission for the user onto the applications directories"
/opt/znuny/bin/znuny.SetPermissions.pl 2>&1>/dev/null 
