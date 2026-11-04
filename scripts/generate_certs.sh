#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Create subdirectories if they do not exist
mkdir -p certs/ca certs/minio certs/backend

echo "=== Generating Unified Self-Signed Root CA & Server Certificate ==="

# Combined SAN covering localhost, MinIO, Backend, and Kind cluster / host networking
SAN="DNS:localhost,DNS:minio,DNS:web_be,DNS:web-be,DNS:localip,DNS:host.docker.internal,IP:127.0.0.1"

# 1. Generate single private key
openssl genrsa -out certs/ca/ca.key 2048

# 2. Generate self-signed certificate with both CA:TRUE and serverAuth/clientAuth
cat <<EOF > certs/unified_ext.cnf
[v3]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyEncipherment,keyCertSign,cRLSign
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = ${SAN}
EOF

MSYS_NO_PATHCONV=1 openssl req -new -x509 -days 1461 \
  -key certs/ca/ca.key \
  -out certs/ca/ca.crt \
  -subj "/CN=Accelerator-Dev-Root-CA" \
  -config <(cat /etc/ssl/openssl.cnf certs/unified_ext.cnf 2>/dev/null || cat certs/unified_ext.cnf) \
  -extensions v3

rm -f certs/unified_ext.cnf

# 3. Propagate to MinIO and Backend mounts
cp -f certs/ca/ca.crt certs/minio/public.crt
cp -f certs/ca/ca.key certs/minio/private.key

cp -f certs/ca/ca.crt certs/backend/public.crt
cp -f certs/ca/ca.key certs/backend/private.key

echo "=== Unified certificate successfully generated and deployed to certs/ ==="
