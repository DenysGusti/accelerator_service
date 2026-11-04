#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

mkdir -p certs

echo "=== Generating Unified Dev Certificate (public.crt & private.key) ==="

SAN="DNS:localhost,DNS:minio,DNS:web_be,DNS:web-be,DNS:localip,DNS:host.docker.internal,IP:127.0.0.1"

# 1. Generate private key
openssl genrsa -out certs/private.key 2048

# 2. Generate self-signed certificate with CA:TRUE and serverAuth/clientAuth
cat <<EOF > certs/unified_ext.cnf
[v3]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyEncipherment,keyCertSign,cRLSign
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = ${SAN}
EOF

MSYS_NO_PATHCONV=1 openssl req -new -x509 -days 1461 \
  -key certs/private.key \
  -out certs/public.crt \
  -subj "/CN=Accelerator-Dev-Root-CA" \
  -config <(cat /etc/ssl/openssl.cnf certs/unified_ext.cnf 2>/dev/null || cat certs/unified_ext.cnf) \
  -extensions v3

rm -f certs/unified_ext.cnf

echo "=== Certificate successfully generated at certs/public.crt and certs/private.key ==="
