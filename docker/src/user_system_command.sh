customLogger "info" "user_system" "Create the system user '${DEFAULT_APP_USER}'"
useradd -d /opt/znuny -c 'Znuny user' -g www-data -s /bin/bash -M -N ${DEFAULT_APP_USER} 2>&1 |\
  for ((i = 0; i < 3; i++)); do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"znuny\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
    sleep 1
  done

zcli user permissions

