customLogger "info" "config_database" "Check the connexion to the PostgreSQL database"
if database_wait_pgsql "${ZNUNY_DATABASE_HOST:-$DEFAULT_ZNUNY_DATABASE_HOST}" \
                       "${ZNUNY_DATABASE_PORT:-$DEFAULT_ZNUNY_DATABASE_PORT}" \
                       "${ZNUNY_DATABASE_NAME:-$DEFAULT_ZNUNY_DATABASE_NAME}" \
                       "${ZNUNY_DATABASE_USER:-$DEFAULT_ZNUNY_DATABASE_USER}" \
                       "${ZNUNY_DATABASE_PASSWORD:-$DEFAULT_ZNUNY_DATABASE_PASSWORD}"; then
  customLogger "info" "config_database" "The PostgreSQL database is available"
else
  customLogger "error" "config_database" "The PostgreSQL database is missing"
  exit 1
fi

if database_check_pgsql "${ZNUNY_DATABASE_HOST:-$DEFAULT_ZNUNY_DATABASE_HOST}" \
                        "${ZNUNY_DATABASE_PORT:-$DEFAULT_ZNUNY_DATABASE_PORT}" \
                        "${ZNUNY_DATABASE_NAME:-$DEFAULT_ZNUNY_DATABASE_NAME}" \
                        "${ZNUNY_DATABASE_USER:-$DEFAULT_ZNUNY_DATABASE_USER}" \
                        "${ZNUNY_DATABASE_PASSWORD:-$DEFAULT_ZNUNY_DATABASE_PASSWORD}"; then
  customLogger "warn" "config_database" "SKIP: The database is not empty"
else
  customLogger "info" "config_database" "Initialize the database schemas"
  database_role_pgsql "${ZNUNY_DATABASE_HOST:-$DEFAULT_ZNUNY_DATABASE_HOST}" \
                      "${ZNUNY_DATABASE_PORT:-$DEFAULT_ZNUNY_DATABASE_PORT}" \
                      "${ZNUNY_DATABASE_NAME:-$DEFAULT_ZNUNY_DATABASE_NAME}" \
                      "${ZNUNY_DATABASE_USER:-$DEFAULT_ZNUNY_DATABASE_USER}" \
                      "${ZNUNY_DATABASE_PASSWORD:-$DEFAULT_ZNUNY_DATABASE_PASSWORD}"
  database_init_pgsql "${ZNUNY_DATABASE_HOST:-$DEFAULT_ZNUNY_DATABASE_HOST}" \
                      "${ZNUNY_DATABASE_PORT:-$DEFAULT_ZNUNY_DATABASE_PORT}" \
                      "${ZNUNY_DATABASE_NAME:-$DEFAULT_ZNUNY_DATABASE_NAME}" \
                      "${ZNUNY_DATABASE_USER:-$DEFAULT_ZNUNY_DATABASE_USER}" \
                      "${ZNUNY_DATABASE_PASSWORD:-$DEFAULT_ZNUNY_DATABASE_PASSWORD}"
fi

