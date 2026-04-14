TMP_LOCK_FILE="/tmp/upgrade.lock"

echo "true" > ${TMP_LOCK_FILE}

function upgrade() {
  su -c "/opt/znuny/scripts/MigrateToZnuny7_3.pl" -s /bin/sh ${DEFAULT_APP_USER}
  
  sleep 1

  echo "false" > ${TMP_LOCK_FILE}
}

customLogger "info" "user_admin" "Ensure the database schemas are up to date"
upgrade 2>&1 |\
while $(cat ${TMP_LOCK_FILE}); do
  if IFS= read -r MESSAGE; then
    if [[ -n "${MESSAGE}" ]]; then
      echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"upgrade\", \"message\":\"${MESSAGE}\"}"
    fi
  fi
done

rm -f ${TMP_LOCK_FILE}


