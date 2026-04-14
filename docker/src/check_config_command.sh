TMP_LOCK_FILE="/tmp/check_config.lock"

echo "true" > ${TMP_LOCK_FILE}

function check_znunys_config() {
  su -c "/opt/znuny/bin/znuny.Console.pl Maint::Config::Rebuild --cleanup" -s /bin/sh ${DEFAULT_APP_USER}

  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}

customLogger "info" "check_config" "Rebuild configuration"
check_znunys_config 2>&1 |\
while $(cat ${TMP_LOCK_FILE}); do
  if IFS= read -r MESSAGE; then
    if [[ -n "${MESSAGE}" ]]; then
      echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"check_config\", \"message\":\"${MESSAGE}\"}"
    fi
  fi
done

rm -f ${TMP_LOCK_FILE}

