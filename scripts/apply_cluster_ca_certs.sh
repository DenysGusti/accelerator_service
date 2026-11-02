#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"

if [ "$#" -eq 0 ]; then
    NAMESPACES=("wkube" "kube-system")
else
    NAMESPACES=("$@")
fi

DEV_CA="${CERTS_DIR}/ca/ca.crt"
PROD_S3="${CERTS_DIR}/prod-s3-internal.crt"

if [[ ! -f "$DEV_CA" ]]; then
    echo "Error: Dev CA cert not found at $DEV_CA. Run generate_certs.sh first." >&2
    exit 1
fi

# Ensure Kind cluster node is connected to the Docker Compose network (for minio/backend resolution)
NODE="desktop-control-plane"
NET="accelerator_service_default"
if command -v docker &>/dev/null && docker inspect "$NODE" &>/dev/null; then
    if ! docker inspect "$NODE" --format '{{json .NetworkSettings.Networks}}' 2>/dev/null | grep -q "$NET"; then
        echo "Connecting cluster node ${NODE} to Docker network ${NET}..."
        docker network connect "$NET" "$NODE" 2>/dev/null || true
    fi
fi

for NAMESPACE in "${NAMESPACES[@]}"; do
    echo "Creating cluster-ca-certs ConfigMap in namespace '${NAMESPACE}' from ${CERTS_DIR}..."

    CMD=(kubectl create configmap cluster-ca-certs
        --from-file="accelerator-dev-ca.crt=${DEV_CA}"
        -n "${NAMESPACE}"
        --dry-run=client -o yaml
    )

    if [[ -f "$PROD_S3" ]]; then
        CMD+=(--from-file="prod-s3-internal.crt=${PROD_S3}")
    fi

    "${CMD[@]}" | kubectl apply -f -

    echo "ConfigMap cluster-ca-certs successfully applied in namespace '${NAMESPACE}'."
done
