TMP_LOCK_FILE="/tmp/config_override.lock"
ZNUNY_CUSTOM_DIRECTORY="/opt/znuny/Custom"

echo "true" > ${TMP_LOCK_FILE}

function set_configurations_overrides() {
  for OVERRIDE_DIR in $(find ${ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY:-$DEFAULT_ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY} -type d -name '*'); do
    mkdir -p "${ZNUNY_CUSTOM_DIRECTORY}/`echo \"${OVERRIDE_DIR}\" | sed \"s*${ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY:-$DEFAULT_ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY}**g\"`"
  done

  for OVERRIDE_FILE in $(find ${ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY:-$DEFAULT_ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY} -type f -name '*'); do
    customLogger "info" "config_override" "Create '${ZNUNY_CUSTOM_DIRECTORY}/`echo \"${OVERRIDE_FILE}\" | sed \"s*${ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY:-$DEFAULT_ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY}**g\"`' from '${OVERRIDE_FILE}'"
    cp -f "${OVERRIDE_FILE}" "${ZNUNY_CUSTOM_DIRECTORY}/`echo \"${OVERRIDE_FILE}\" | sed \"s*${ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY:-$DEFAULT_ZNUNY_CONFIGURATIONS_OVERRIDES_DIRECTORY}**g\"`"
  done

  sleep 1
  echo "false" > ${TMP_LOCK_FILE}
}

customLogger "info" "config_override" "Configure custom configurations overrides"
set_configurations_overrides 2>&1 |\
  while $(cat ${TMP_LOCK_FILE}); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"config_override\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

rm -f ${TMP_LOCK_FILE}
