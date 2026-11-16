# DEBUG_MODE takes 0 or 1 as a value. 0 = False, 1 = True.
DEBUG_MODE=1
IIASA_MICROSOFT_OPENID_ISSUER_WELL_KNOWN_CONF=https://login.microsoftonline.com/9b79b10b-0007-4e8a-b072-asdfgcdc1aa5/v2.0/.well-known/openid-configuration
BUCKET_DETAILS_ENCRYPTION_KEY=<base-64-encoded_256-bit_key>
# ES256
JWT_BASE64_PRIVATE_KEY=<mocked>
JWT_BASE64_PUBLIC_KEY=<mocked>
REFRESH_TOKEN_SECRET_KEY=<mocked>
ALLOWED_ORIGINS=["http://localhost:8080","https://localhost:8080","https://localhost:8081","http://localhost:8008","https://localhost:8008"]

INITIAL_S3_ENDPOINT=https://minio:9000
INITIAL_S3_API_KEY=<MinIO_Access_Key>
INITIAL_S3_SECRET_KEY=<MinIO_Secret_Key>
INITIAL_S3_BUCKET_NAME=accelerator

XET_CAS_S3_ENDPOINT_INTERNAL=https://minio:9000
XET_CAS_S3_ENDPOINT=https://minio:9000
XET_CAS_S3_API_KEY=<MinIO_Access_Key>
XET_CAS_S3_SECRET_KEY=<MinIO_Secret_Key>
XET_CAS_S3_BUCKET_NAME=accelerator

PYTHONASYNCIODEBUG=1
PYTHONDEVMODE=1
CELERY_BROKER_URL=redis://:myredispassword@redis:6379/1
XET_REDIS_URL=redis://:myredispassword@redis:6379/0

SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
ACCELERATOR_EMAIL=https://localhost:8000

FRONTEND_URL=https://localhost:8000

JOB_SECRET_ENCRYPTION_KEY=<base-64-encoded_256-bit_key>

JOBSTORE_S3_ENDPOINT=https://minio:9000
JOBSTORE_S3_API_KEY=<MinIO_Access_Key>
JOBSTORE_S3_SECRET_KEY=<MinIO_Secret_Key>
JOBSTORE_S3_BUCKET_NAME=jobstore

OPENAI_API_KEY=<mocked>
OPENAI_API_BASE=https://api.openai.com/v1

GCP_SERVICE_ACCOUNT_BASE64_JSON=<mocked>
TEAMS_WEBHOOK_URL=<mocked>

ACCELERATOR_CLI_BASE_URL=https://web-be:8000
WKUBE_AGENT_PULLER=wrufesh/wkube-agent-puller
IMAGE_REGISTRY_URL=registry:8443
IMAGE_REGISTRY_TAG_PREFIX=
IMAGE_REGISTRY_USER=myregistry
IMAGE_REGISTRY_PASSWORD=myregistrypassword
OCI_BUILDER_IMAGE=wrufesh/wkube-image-builder
WKUBE_K8_NAMESPACE=wkube
WKUBE_SECRET_JSON_B64=<mocked>

WKUBE_WORKFLOW_STORAGE_CLASS=local-path

#Dev specific
DOCKER_TLS_VERIFY=
DOCKER_CERT_PATH=

ACCELERATOR_APP_TOKEN=<mocked>
TUNNEL_GATEWAY_SSH_PRIVATE_KEY_BASE64=<base-64-encoded_private_key>

USE_HOST_NAMESPACES=0

ENABLE_HF_ACC_CSI=1

RECON_APP_BASE_URL=https://localhost:8900
