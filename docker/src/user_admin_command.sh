TMP_LOCK_FILE="/tmp/user_admin.lock"

echo "true" > ${TMP_LOCK_FILE}

function set_admin_user() {
  su -c "/opt/znuny/bin/znuny.Console.pl Admin::User::Add --user-name ${ZNUNY_USER_ADMIN_NAME:-$DEFAULT_ZNUNY_USER_ADMIN_NAME} --first-name ${ZNUNY_USER_ADMIN_NAME:-$DEFAULT_ZNUNY_USER_ADMIN_NAME} --last-name ${ZNUNY_USER_ADMIN_NAME:-$DEFAULT_ZNUNY_USER_ADMIN_NAME} --email-address ${ZNUNY_USER_ADMIN_NAME:-$DEFAULT_ZNUNY_USER_ADMIN_NAME}@${ZNUNY_APACHE_DOMAIN:-$DEFAULT_ZNUNY_APACHE_DOMAIN} --password ${ZNUNY_USER_ADMIN_PASSWORD:-$DEFAULT_ZNUNY_USER_ADMIN_PASSWORD}" -s /bin/sh ${DEFAULT_APP_USER} || true
  su -c "/opt/znuny/bin/znuny.Console.pl Admin::Group::UserLink --user-name ${ZNUNY_USER_ADMIN_NAME:-$DEFAULT_ZNUNY_USER_ADMIN_NAME} --group-name admin --permission rw" -s /bin/sh ${DEFAULT_APP_USER} || true
  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}

customLogger "info" "user_admin" "Create the application admin user ${ZNUNY_USER_ADMIN_NAME:-$DEFAULT_ZNUNY_USER_ADMIN_NAME}"
set_admin_user 2>&1 |\
  while $(cat ${TMP_LOCK_FILE}); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"user_admin\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

rm -f ${TMP_LOCK_FILE}



