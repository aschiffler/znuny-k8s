customLogger "info" "run" "Launch the web server"
touch /opt/znuny/healthy
/usr/sbin/apache2ctl -D FOREGROUND 2>&1 | \
  while true; do
    if IFS= read -r MESSAGE; then
      if [[ -n "${MESSAGE}" ]]; then
        echo -e "{\"timestamp\":\"$(date +'%Y-%m-%d %H:%M:%S')\", \"source\":\"znuny\", \"message\":\"${MESSAGE}\"}"
      fi
    fi
  done

