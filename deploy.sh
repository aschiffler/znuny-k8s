#!/usr/bin/env bash
# Deploy znuny from scratch to the local k8s cluster.
# Usage: ./deploy.sh
# Prerequisites: kubectl, microk8s helm3, local registry at localhost:32000

set -euo pipefail

NAMESPACE=znuny
REGISTRY=10.152.183.235:5000
KEYCLOAK_METADATA_URL=https://keycloak.thws.education/realms/thws/protocol/saml/descriptor
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- helpers ----------
info()  { echo "[INFO]  $*"; }
die()   { echo "[ERROR] $*" >&2; exit 1; }

require_env() {
  [[ -n "${!1:-}" ]] || die "Environment variable $1 is required"
}

# ---------- load .env ----------
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -o allexport
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +o allexport
  info "Loaded .env from $SCRIPT_DIR"
fi

# ---------- required env vars ----------
require_env GH_TOKEN       # GitHub PAT to clone znuny-k8s repo for Kaniko build
require_env DB_PASSWORD    # PostgreSQL / Znuny DB password
require_env ADMIN_PASSWORD # Znuny admin user password

# ---------- 1. namespace ----------
info "Creating namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ---------- 2. secrets ----------
info "Creating secrets"

kubectl create secret generic znuny-db-password \
  --from-literal=password="$DB_PASSWORD" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic znuny-db-password-helm \
  --from-literal=ZNUNY_DATABASE_USER=znuny \
  --from-literal=ZNUNY_DATABASE_PASSWORD="$DB_PASSWORD" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic znuny-admin-password \
  --from-literal=ZNUNY_USER_ADMIN_NAME=admin \
  --from-literal=ZNUNY_USER_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic znuny-build-secret \
  --from-literal=github-token="$GH_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# ---------- 3. PostgreSQL ----------
info "Deploying PostgreSQL"
kubectl apply -f "$SCRIPT_DIR/postgres.yaml"
kubectl wait --for=condition=available deployment/postgres -n "$NAMESPACE" --timeout=120s

# ---------- 4. Build image ----------
info "Building Znuny image with Kaniko"
kubectl delete job znuny-kaniko-build --ignore-not-found=true
kubectl apply -f "$SCRIPT_DIR/kaniko-build-job.yaml"

info "Waiting for Kaniko build to complete (this takes ~20 min)..."
kubectl wait --for=condition=complete job/znuny-kaniko-build --timeout=30m
info "Image pushed to ${REGISTRY}/znuny:7.3"

# ---------- 5. Helm install ----------
info "Installing Znuny Helm chart"
microk8s helm3 upgrade --install znuny "$SCRIPT_DIR/helm" \
  --namespace "$NAMESPACE" \
  -f "$SCRIPT_DIR/values-thws.yaml" \
  --wait --timeout 8m

# ---------- 6. SAML certificates ----------
info "Setting up SAML certificates in overrides PVC"
POD=$(kubectl get pod -n "$NAMESPACE" -l app=znuny -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n "$NAMESPACE" "$POD" -- bash -c "
  mkdir -p /overrides/SAML

  # Generate SP certificate and key
  if [[ ! -f /overrides/SAML/sp.key ]]; then
    openssl req -x509 -newkey rsa:2048 \
      -keyout /overrides/SAML/sp.key \
      -out    /overrides/SAML/sp.crt \
      -days 3650 -nodes \
      -subj '/CN=ticket.thws.education/O=THWS/C=DE' 2>/dev/null
    echo 'Generated new SP certificate'
  else
    echo 'SP certificate already exists, skipping'
  fi

  # Download IdP certificate from Keycloak
  curl -sk '$KEYCLOAK_METADATA_URL' | \
    grep -oP '(?<=<ds:X509Certificate>)[^<]+' | head -1 | \
    awk 'BEGIN{print \"-----BEGIN CERTIFICATE-----\"} {gsub(/.{64}/,\"&\n\")} {print} END{print \"-----END CERTIFICATE-----\"}' \
    > /overrides/SAML/idp.crt

  chown -R znuny:www-data /overrides/SAML/
  chmod 640 /overrides/SAML/sp.key
  chmod 644 /overrides/SAML/sp.crt /overrides/SAML/idp.crt

  echo 'SAML certs:'
  openssl x509 -in /overrides/SAML/sp.crt  -noout -subject -dates
  openssl x509 -in /overrides/SAML/idp.crt -noout -subject -dates
"

info "Done — Znuny is available at https://ticket.thws.education/znuny/index.pl"
info ""
info "Next steps:"
info "  1. Import znuny-sp-metadata.xml into Keycloak (thws realm → Clients → Import)"
info "  2. Set Keycloak client Name ID Format to 'Email'"
info "  3. Create Znuny agents with login = their email address"
