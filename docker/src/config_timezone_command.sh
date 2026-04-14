TMP_LOCK_FILE="/tmp/config_timezone.lock"

echo "true" > ${TMP_LOCK_FILE}

function set_timezone() {
  rm -f /etc/localtime
  cp -f "/usr/share/zoneinfo/${ZNUNY_TIMEZONE:-$DEFAULT_ZNUNY_TIMEZONE}" /etc/localtime
  echo "${ZNUNY_TIMEZONE:-$DEFAULT_ZNUNY_TIMEZONE}" > /etc/timezone

  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}


customLogger "info" "config_timezone" "Configure the timezone"
set_timezone 2>&1 |\
  while $(cat ${TMP_LOCK_FILE}); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"config_timezone\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

rm -f ${TMP_LOCK_FILE}
