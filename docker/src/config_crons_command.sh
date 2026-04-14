CRONS_PATH="/opt/znuny/var/cron"

customLogger "info" "config_cron" "Create crons"
for CRON in $(ls ${CRONS_PATH}/*.dist); do
  cp ${CRON} $(basename $foo .dist)
done
