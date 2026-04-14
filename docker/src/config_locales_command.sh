TMP_LOCK_FILE="/tmp/config_locales.lock"

echo "true" > ${TMP_LOCK_FILE}

function set_locales() {
  sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  sed -i 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen
  echo "LANG="en_US.UTF-8"" > /etc/default/locale
  locale -a

  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}


customLogger "info" "config_locales" "Configure locale environment"
set_locales 2>&1 |\
  while $(cat ${TMP_LOCK_FILE}); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"config_locales\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

rm -f ${TMP_LOCK_FILE}
