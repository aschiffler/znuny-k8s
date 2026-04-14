APACHE_CONFIG_PATH="/etc/apache2/apache2.conf"

function gen_add_apache2_main_conf() {
  DOMAIN=${1}
  CONTENT=$(cat << EOF > ${APACHE_CONFIG_PATH}
ServerName ${DOMAIN}
DefaultRuntimeDir \${APACHE_RUN_DIR}
PidFile \${APACHE_PID_FILE}
Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
User \${APACHE_RUN_USER}
Group \${APACHE_RUN_GROUP}
HostnameLookups Off
ErrorLog \${APACHE_LOG_DIR}/error.log
LogLevel info
IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
Include ports.conf
# <Directory />
# 	Options FollowSymLinks
# 	AllowOverride None
# 	Require all denied
# </Directory>
#
# <Directory /usr/share>
# 	AllowOverride None
# 	Require all granted
# </Directory>
#
# <Directory /var/www/>
# 	Options Indexes FollowSymLinks
# 	AllowOverride None
# 	Require all granted
# </Directory>
#
# AccessFileName .htaccess
# <FilesMatch "^\.ht">
# 	Require all denied
# </FilesMatch>

LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent
LogFormat "{\"time\":\"%t\",\"remoteIP\":\"%a\",\"host\":\"%V\",\"request\":\"%U\",\"query\":\"%q\",\"method\":\"%m\",\"status\":\"%>s\",\"userAgent\":\"%{User-agent}i\",\"referer\":\"%{Referer}i\"}" znuny

IncludeOptional conf-enabled/*.conf

EOF
)
}


