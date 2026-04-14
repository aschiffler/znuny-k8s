customLogger "info" "run" "Launch Crons of Znuny"
su -c "/opt/znuny/bin/Cron.sh start" -s /bin/sh ${DEFAULT_APP_USER} 2>&1 | \
  while true; do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"znuny\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

