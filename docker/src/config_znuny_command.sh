CONFIG_PATH="/opt/znuny/Kernel/Config.pm"

if [[ -z ${ZNUNY_SETTINGS_FILE} ]]; then
  customLogger "info" "config_znuny" "Check if the config file already exists"
  if [[ -f "${CONFIG_PATH}" ]]; then
    customLogger "warn" "config_znuny" "The configuration file of Znuny already exists and will be replaced"
    rm ${CONFIG_PATH}
  fi

  customLogger "info" "config_znuny" "Create the configuration of Znuny"
  touch ${CONFIG_PATH}

  customLogger "info" "config_znuny" "Generate the licence"
  gen_add_licence

  customLogger "info" "config_znuny" "Generate packages"
  gen_add_package

  customLogger "info" "config_znuny" "Generate uses"
  gen_add_use

  customLogger "info" "config_znuny" "Generate sub"
  gen_add_sub

  customLogger "info" "config_znuny" "Generate database connection"
  gen_add_database_credentials "${ZNUNY_DATABASE_HOST:-$DEFAULT_ZNUNY_DATABASE_HOST}" \
                              "${ZNUNY_DATABASE_NAME:-$DEFAULT_ZNUNY_DATABASE_NAME}" \
                              "${ZNUNY_DATABASE_USER:-$DEFAULT_ZNUNY_DATABASE_USER}" \
                              "${ZNUNY_DATABASE_PASSWORD:-$DEFAULT_ZNUNY_DATABASE_PASSWORD}"

  customLogger "info" "config_znuny" "Generate the database driver"
  gen_add_database_postgresql

  customLogger "info" "config_znuny" "Generate the filesystem root directory"
  gen_add_fs_root_dir

  customLogger "info" "config_znuny" "Generate mailing configurations"
  case ${ZNUNY_MAILING_TYPE:-$DEFAULT_ZNUNY_MAILING_TYPE} in
    "sendmail")
      gen_add_mailing_sendmail 
      ;;
    "smtp")
      gen_add_mailing_smtp ${ZNUNY_MAILING_HOST} ${ZNUNY_MAILING_PORT} ${ZNUNY_MAILING_USER} ${ZNUNY_MAILING_PASSWORD}
      ;;
  esac

  customLogger "info" "config_znuny" "Generate users authentications"
  if [[ ! -z ${ZNUNY_AUTHENTICATIONS_BACKENDS} ]]; then
    gen_add_authentication "${ZNUNY_AUTHENTICATIONS_BACKENDS}"
  fi

  customLogger "info" "config_znuny" "Generate the secure mode state"
  gen_add_securemode ${ZNUNY_SECURE_MODE:-$DEFAULT_ZNUNY_SECURE_MODE}

  customLogger "info" "config_znuny" "Generate the application timezone"
  gen_add_timezone ${ZNUNY_TIMEZONE:-$DEFAULT_ZNUNY_TIMEZONE}

  if [[ ! -z ${ZNUNY_HEALTHSTATUS_APIKEY} ]]; then
    customLogger "info" "config_znuny" "Generate the healthstatus api key"
    gen_add_healthstatus_apikey "${ZNUNY_HEALTHSTATUS_APIKEY}"
  fi

  customLogger "info" "config_znuny" "Generate logging configurations"
  if [[ -z ${ZNUNY_LOG_PATH} ]]; then
    gen_add_log_rsyslog 
  else
    gen_add_log_file "${ZNUNY_LOG_PATH}"
    APP_USER="znuny"
    touch /var/log/znuny
    chown ${DEFAULT_APP_USER} /var/log/znuny
  fi

  customLogger "info" "config_znuny" "Generate the configuration return"
  gen_add_return

  customLogger "info" "config_znuny" "Generate the system stuffs"
  gen_add_system_stuff

  customLogger "info" "config_znuny" "End file"
  gen_add_end
else
  customLogger "info" "config_znuny" "Create the configuration file from a single variable"
  echo -e ${ZNUNY_SETTINGS_FILE} > ${CONFIG_PATH}
fi