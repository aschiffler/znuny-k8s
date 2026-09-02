CONFIG_ZNUNY_VERSION=${args[-r]}
CONFIG_ZNUNY_CHECKSUM=${args[-s]}

DESTINATION="/tmp/znuny-${CONFIG_ZNUNY_VERSION}.tar.gz"

customLogger "info" "download" "Download the version ${CONFIG_ZNUNY_VERSION} of the archive of Znuny"
curl -fsS \
  -o ${DESTINATION} \
  https://download.znuny.org/releases/znuny-${CONFIG_ZNUNY_VERSION}.tar.gz

customLogger "info" "download" "Check the archive integrity"
COMPUTED_CHECKSUM=$(sha256sum ${DESTINATION} | awk '{print $1}')
if [ "${COMPUTED_CHECKSUM}" != "${CONFIG_ZNUNY_CHECKSUM}" ]; then
    customLogger "error" "download" "The archive of the version ${CONFIG_ZNUNY_VERSION} of Znuny failed the sha256 check: expected ${CONFIG_ZNUNY_CHECKSUM}, got ${COMPUTED_CHECKSUM}"
    rm -f ${DESTINATION}
    exit 1
fi

customLogger "info" "download" "Extract the source code"
tar -xzf ${DESTINATION} -C /opt/znuny --strip-components=1

customLogger "info" "download" "Delete the archive of Znuny"
rm -f ${DESTINATION}

