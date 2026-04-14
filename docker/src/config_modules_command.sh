TMP_LOCK_FILE="/tmp/config_modules.lock"

function check_modules_packages() {
  if [[ -z ${ZNUNY_ADDONS} ]]; then
    echo -e "No extensions defined"
  else
    IFS=','

    for ADDON in ${ZNUNY_ADDONS}; do
      if su -c "/opt/znuny/bin/znuny.Console.pl Admin::Package::FileSearch ${ADDON##*:}" -s /bin/bash znuny 2>&1 | grep -q 'Error' ; then
        echo -e "** Install the extention '${ADDON}'"
        su -c "/opt/znuny/bin/znuny.Console.pl Admin::Package::Install ${ADDON}" -s /bin/bash znuny 1> /dev/null || true
      else
        echo -e "** Reinstall the extention '${ADDON}'"
        su -c "/opt/znuny/bin/znuny.Console.pl Admin::Package::Reinstall ${ADDON}" -s /bin/bash znuny 1> /dev/null || true
      fi
    done
    
    unset IFS
  fi

  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}

echo "true" > ${TMP_LOCK_FILE}

customLogger "info" "check_modules" "Install application extensions"
check_modules_packages 2>&1 |\
  while $(cat ${TMP_LOCK_FILE}); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"check_modules\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

rm -f ${TMP_LOCK_FILE}



