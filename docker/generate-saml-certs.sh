#!/usr/bin/env bash
# Generate the SP key/cert and fetch the Keycloak IdP cert into
# docker/overrides/SAML/, the same way deploy.sh does it on the /overrides
# PVC in the k8s deployment. Run this once before `docker compose up`.
# docker/overrides/SAML/ is gitignored — private key material never gets committed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAML_DIR="$SCRIPT_DIR/overrides/SAML"
DOMAIN="${ZNUNY_APACHE_DOMAIN:-ticket.thws.education}"
KEYCLOAK_METADATA_URL="${KEYCLOAK_METADATA_URL:-https://keycloak.thws.education/realms/thws/protocol/saml/descriptor}"

mkdir -p "$SAML_DIR"

if [[ ! -f "$SAML_DIR/sp.key" ]]; then
  openssl req -x509 -newkey rsa:2048 \
    -keyout "$SAML_DIR/sp.key" \
    -out    "$SAML_DIR/sp.crt" \
    -days 3650 -nodes \
    -subj "/CN=${DOMAIN}/O=THWS/C=DE" 2>/dev/null
  echo "Generated new SP certificate for CN=${DOMAIN}"
else
  echo "SP certificate already exists, skipping"
fi

curl -sk "$KEYCLOAK_METADATA_URL" | \
  grep -oP '(?<=<ds:X509Certificate>)[^<]+' | head -1 | \
  awk 'BEGIN{print "-----BEGIN CERTIFICATE-----"} {gsub(/.{64}/,"&\n")} {print} END{print "-----END CERTIFICATE-----"}' \
  > "$SAML_DIR/idp.crt"

# 644, not 600: this is bind-mounted into the container, where the znuny/
# www-data user has a different UID than your host user and can't read a
# host-restricted 600 file (confirmed live: Net::SAML2 raised "Permission
# denied" on sp.key and every SAML-touching request 500'd). Fine for a local
# dev/test self-signed cert; don't reuse this relaxed mode for a real
# production private key living on a shared bind mount.
chmod 644 "$SAML_DIR/sp.key" "$SAML_DIR/sp.crt" "$SAML_DIR/idp.crt"

echo "SAML certs written to $SAML_DIR:"
openssl x509 -in "$SAML_DIR/sp.crt"  -noout -subject -dates
openssl x509 -in "$SAML_DIR/idp.crt" -noout -subject -dates

echo
echo "Next: regenerate the SP metadata XML from sp.crt (see znuny-sp-metadata.xml"
echo "for the shape) and (re-)import it into the Keycloak client, since the SP"
echo "cert here is freshly self-signed and won't match what's currently registered."
