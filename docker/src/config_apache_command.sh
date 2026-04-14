gen_add_apache2_main_conf "${ZNUNY_APACHE_DOMAIN:-$DEFAULT_ZNUNY_APACHE_DOMAIN}"

customLogger "info" "config_apache" "Create the virtualhost to expose Znuny"
ln -s /opt/znuny/scripts/apache2-httpd.include.conf /etc/apache2/conf-available/zzz_znuny.conf || true

customLogger "info" "config_apache" "Enable then add rewrite rules"
if [[ ! -z ${ZNUNY_APACHE_REWRITE_RULES} ]]; then
  customLogger "info" "config_apache" "Enable the rewrite module"
  a2enmod rewrite 2>&1>/dev/null

  echo -e "\n###\n#Add custom rewrite rules\n###" >> /etc/apache2/conf-available/zzz_znuny.conf
  echo "<IfModule mod_rewrite.c>" >> /etc/apache2/conf-available/zzz_znuny.conf
  echo "    RewriteEngine on" >> /etc/apache2/conf-available/zzz_znuny.conf

  while IFS= read -r RULE; do
    echo "    ${RULE}" >> /etc/apache2/conf-available/zzz_znuny.conf
  done <<< "${ZNUNY_APACHE_REWRITE_RULES}"

  echo -e "</IfModule>\n" >> /etc/apache2/conf-available/zzz_znuny.conf
fi

customLogger "info" "config_apache" "Enable OIDC"
if [[ ! -z ${ZNUNY_APACHE_OIDC} ]]; then
  customLogger "info" "config_apache" "Config OIDC"
  
  echo -e "\n###\n#Add OIDC\n###" >> /etc/apache2/conf-available/zzz_znuny.conf

fi

echo -e "CustomLog \${APACHE_LOG_DIR}/znuny.log znuny" >> /etc/apache2/conf-available/zzz_znuny.conf

customLogger "info" "config_apache" "Enable headers the module"
a2enmod perl headers 2>&1>/dev/null

customLogger "info" "config_apache" "Enable deflate the module"
a2enmod perl deflate 2>&1>/dev/null

customLogger "info" "config_apache" "Enable filter the module"
a2enmod perl filter 2>&1>/dev/null

customLogger "info" "config_apache" "Enable cgi the module"
a2enmod perl cgi 2>&1>/dev/null

customLogger "info" "config_apache" "Disable useless Apache modules"
a2dismod mpm_event 2>&1>/dev/null

customLogger "info" "config_apache" "Enable mpm_prefork"
a2enmod mpm_prefork 2>&1>/dev/null

customLogger "info" "config_apache" "Enable the virtualhost to expose Znuny"
a2enconf zzz_znuny 2>&1>/dev/null


