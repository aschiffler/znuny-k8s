TMP_LOCK_FILE="/tmp/check_modules.lock"

function check_modules_perl() {
  su -c "/opt/znuny/bin/znuny.CheckModules.pl --all 2>&1>/dev/null" -s /bin/bash ${DEFAULT_APP_USER}

  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}

echo "true" > ${TMP_LOCK_FILE}

customLogger "info" "check_modules" "Check Perl modules"
check_modules_perl 2>&1 |\
  while $(cat ${TMP_LOCK_FILE}); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"check_modules\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

rm -f ${TMP_LOCK_FILE}



