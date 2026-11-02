# How to configure and start Accelerator services for local development

## Prerequisites

1. A Docker runtime on your development machine.
2. A Kubernetes cluster, either on your development machine or remotely.
    * **Warning:** Docker Desktop on Windows has issues with building and Wine.
    * On Linux, success has been had with Rancher desktop.

## Services

To set up the services, copy the default Docker compose `.env*` files from the `sample_dotenv/` folder into the working
directory root (containing this `README.md`). Beware: these files have a leading dot and are normally hidden. Customize
the copied `.env*` files as described below, taking into account that default values enclosed by angular brackets (
`<something>`) must be overridden.

The current working directory when issuing `docker compose` commands must be the `accelerator_service` working directory
root. For development work, at a minimum run the frontend, backend, scheduler, TiTiler, and MinIO.

### `.env`

Sets various paths pointing to Accelerator subsystems accessible on your development machine. The `*PROJECT_FOLDER` and
`TITILER_FOLDER` settings should point to the working directories of Accelerator-related Git repositories. The default
values indicate the name of the repository. For example,

```
ACCMS_PROJECT_FOLDER='<path to>/accms'
```

indicates that you have to locate the `accms` repository by [searching for repositories marked with the
`accelerator` topic under the IIASA GitHub organization](https://github.com/search?q=org%3Aiiasa%20topic%3Aaccelerator&type=repositories),
clone it somewhere convenient, and point `ACCMS_PROJECT_FOLDER` at the resulting working directory.

> [!CAUTION]
> Relative paths (relative to the `accelerator_service` working directory root) should start with `./` to avoid being
> mistaken for a volume name.

### Database

1. Execute `docker compose -f docker-compose.dev.yml up db [--build]` to start the service and optionally (re)build the
   image.
2. Enter the db container with `docker exec -it <db container ID> /bin/bash`
3. Create databases inside the container with:
    - `su -- postgres -c "createdb accelerator"`
    - `su -- postgres -c "createdb acceleratortest"`
    - `su -- postgres -c "createdb accms"`
    - `su -- postgres -c "createdb thrd"`
4. When a database already exists, you may wish to drop it first to start with a clean state:
    - `su -- postgres -c "dropdb accelerator"`
    - `su -- postgres -c "dropdb acceleratortest"`
    - `su -- postgres -c "dropdb accms"`
    - `su -- postgres -c "dropdb thrd"`

### TLS Certificates (`certs/`)

All development TLS certificates are centralized in `certs/` and signed by a single **Dev Root CA** (`certs/ca/ca.crt`).

To generate/regenerate certificates for all services (Root CA, MinIO, and Backend):
```bash
./scripts/generate_certs.sh
```

To import the certificates into Windows Root store (auto-elevates to Administrator if needed):
```powershell
.\scripts\import_certs_certutil.ps1
```

| Path | Purpose |
|---|---|
| `certs/ca/ca.crt` | Development Root CA certificate (trust anchor for clients, containers, and OS trust store) |
| `certs/ca/ca.key` | Development Root CA private key |
| `certs/minio/` | Leaf server cert (`public.crt`), private key (`private.key`), for MinIO |
| `certs/backend/` | Leaf server cert (`public.crt`) and private key (`private.key`) mounted into backend service |
| `certs/prod-s3-internal.crt` | IIASA ICT Root CA for internal S3 access |

### MinIO (block storage, S3)

1. Generate TLS certificates (if not already done):
   ```bash
   ./scripts/generate_certs.sh
   ```
2. Start the service:
   ```
   docker compose -f docker-compose.dev.yml up minio [--build]
   ```
   Optionally use the `--build` flag to allow image to be rebuilt if needed. This ensures the containers pick up code
   changes, updated dependencies, and any modifications to the build specification (`Dockerfile`).
3. Access MinIO container via `docker exec` or GUI.
4. Register the local instance.
   ```
   mc alias set local https://localhost:9000 admin adminpassword --insecure
   ```
5. Create required buckets.
   ```
   mc mb local/accelerator --insecure
   mc mb local/jobstore --insecure
   ```
6. Generate access key and secret key.
   ```
   mc admin accesskey create local/ --insecure
   ```
7. In `.env.web.be`, set these as values of the `*_S3_API_KEY=` and `*_S3_SECRET_KEY=` entries.
8. Add the MinIO endpoint to your system's known hosts.

### Registry

Generate `htpasswd` file:

1. `docker pull httpd:2`
2. `docker run --rm --entrypoint htpasswd httpd:2 -Bbn myregistry myregistrypassword > registry_auth/htpasswd`

### Backend (`.env.web.be`)

Aside from the self-explanatory settings...

1. Set `JOB_SECRET_ENCRYPTION_KEY` to the base64-encoded representation of random 256-bit key values which you can
   obtain as follows:

```
head </dev/random -c32 | base64
```

This key encrypts secrets required by jobs.

2. Set `BUCKET_DETAILS_ENCRYPTION_KEY` to the base64-encoded representation of random 256-bit key values which you can
   obtain as follows:

```
head </dev/random -c32 | base64
```

This key encrypts bucket credentials.

Need a public/private keypair. Tokens are signed with the private key by the backend, and can be verified with the
public key. This is useful for example for the gateway for interactive containers: the gateway simply verifies the token
via the public key as obtained via the `GET` method at
`https://accelerator-api.iiasa.ac.at/docs#/.well-known/jwks.json`.

3. Use OpenSSL to generate the keypair and extract the public key:

```
openssl ecparam -genkey -name prime256v1 -noout -out private_key.pem
openssl ec -in private_key.pem -pubout -out public_key.pem
```

4. Set `JWT_BASE64_PRIVATE_KEY` to the base64-encoded representation of your private key which you can obtain as
   follows:

```
base64 -w0 private_key.pem
```

5. Set `JWT_BASE64_PUBLIC_KEY` to the base64-encoded representation of your public key which you can obtain as follows:

```
base64 -w0 public_key.pem
```

### `.env.web.be` (job dispatcher)

Never wrap values in quotes in a Docker `.env` file unless your application explicitly expects those quotation marks to
be part of the actual string.

### Job Dispatcher (`.env.web.be`)

`IMAGE_REGISTRY_TAG_PREFIX` is needed when the registry is subdivided in namespaces. For example Harbor uses projects.
If so, set the name of your space/project followed by a slash as value.

- When the registry service is running, you should be able to log in via  `docker login <registry>:8443` and the
  configured username and password.

1. Convert your Kubernetes config into a base64 string for `WKUBE_SECRET_JSON_B64`:
   - If using Docker Desktop / WSL, the server endpoint in the kubeconfig should point to `https://host.docker.internal:<port>` (the port can be found with `kubectl cluster-info`).
   - You can generate the UTF-8 encoded base64 value in one step:
     ```bash
     # Linux / WSL
     kubectl config view --raw -o json | sed 's/127\.0\.0\.1/host.docker.internal/g' | base64 -w0
     ```
     Or in PowerShell (copies directly to clipboard):
     ```powershell
     $json = (kubectl config view --raw -o json) -replace '127\.0\.0\.1', 'host.docker.internal'
     [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json)) | Set-Clipboard
     ```
   - Paste the output string as the value of `WKUBE_SECRET_JSON_B64` in `.env.web.be`.
2. Set `ACCELERATOR_APP_TOKEN` by obtaining a token as follows:
    - Startup the backend service:  
      `docker compose up web_be`
        - This also starts the integrated frontend.
    - Create an account for yourself by signing in to the front end at `https://localhost:8080/` or
      `https://localhost:8000/`.
        - Press the "Login with IIASA" button.
    - With `docker ps`, determine the container ID of the backend and shell into the container:  
      `docker ps | grep web_be`  
      `docker exec -it <backend container ID> /bin/bash`
    - Grant your account superuser rights:  
      `python apply.py add_role <your email> APP__SUPERUSER`
    - Obtain an access token with superuser rights:  
      `python apply.py get_access_token <your email> <seconds to expiry>`
    - Copy and paste the token as the value of `ACCELERATOR_APP_TOKEN`.
3. Set `USE_HOST_NAMESPACES` to `1` if you use WSL.
4. Apply the Kubernetes Local Setup Manifest (creates `wkube` namespace, storage classes, and bridges):
   ```bash
   kubectl apply -f k8s/manifests/k8s-local-setup.yaml
   ```
5. Apply the CA certificates into `wkube` and `kube-system` namespaces:
   ```bash
   # Linux / macOS / Git Bash:
   ./scripts/apply_cluster_ca_certs.sh

   # Windows PowerShell:
   .\scripts\apply_cluster_ca_certs.ps1
   ```
6. Run the Accelerator CSI Driver locally (for `/mnt/wdrv` support):
   When jobs require project space access (`/mnt/wdrv`), the `hf.csi.accelerator` driver dynamically mounts project buckets into worker pods using `hf-mount`.
   - Apply the CSI driver and local DaemonSet:
     ```bash
     kubectl apply -f ../hf-csi-driver/deploy/kubernetes/crd.yaml -f ../hf-csi-driver/deploy/kubernetes/serviceaccount.yaml -f ../hf-csi-driver/deploy/kubernetes/rbac.yaml -f k8s/manifests/hf-csi-node.yaml
     ```
   - (Optional - Local Build): If developing or modifying `hf-csi-driver` code locally instead of using published images:
     1. Build the image locally from source:
        ```bash
        docker build -t ghcr.io/wrufesh/hf-csi-driver:v0.9.2-acc-p11 ../hf-csi-driver
        ```
     2. Import the image into your local cluster node (`desktop-control-plane`):
        ```bash
        # Linux / macOS / Git Bash:
        docker save ghcr.io/wrufesh/hf-csi-driver:v0.9.2-acc-p11 | docker exec -i desktop-control-plane ctr -n k8s.io images import -
        ```
        ```powershell
        # Windows PowerShell (avoiding binary pipeline corruption):
        cmd.exe /c "docker save ghcr.io/wrufesh/hf-csi-driver:v0.9.2-acc-p11 | docker exec -i desktop-control-plane ctr -n k8s.io images import -"
        ```
     3. Restart the DaemonSet:
        ```bash
        kubectl rollout restart daemonset/hf-csi-node -n kube-system
        ```
7. Recreate backend services to ensure updated `.env.web.be` settings (Kubeconfig, ports, namespaces) are active:
   ```bash
   docker compose -f docker-compose.dev.yml up -d --force-recreate k8s_events scheduler web_be
   ```

### [TiTiler](https://developmentseed.org/titiler/) (tile server)

1. Clone the repo `https://github.com/iiasa/meta-titiler`
2. Point `TITILER_FOLDER` in `.env` at the resulting working directory.
3. Check that a certificate is present in `certs`. If absent, create a self-signed certificate for TiTiler by issuing:
   ```
   cd meta-titiler
   mkdir certs
   cd certs
   openssl genrsa -out ca.key 2048 && \
   openssl req -new -x509 -days 1461 -key ca.key -out ca.crt -subj "/CN=localhost" \
   -addext "basicConstraints=critical,CA:TRUE" \
   -addext "keyUsage=critical,keyCertSign,cRLSign" && \
   openssl genrsa -out private.key 2048 && \
   openssl req -new -key private.key -out server.csr -subj "/CN=localhost" && \
   openssl x509 -req -days 1461 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out public.crt \
   -extfile <(printf "[v3]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:localip,DNS:web_be,DNS:localhost,DNS:minio,IP:127.0.0.1,DNS:host.docker.internal") \
   -extensions v3
   cd ..
   ```

### Frontend (`.env.web.fe`)

Must use https with TiTiler and hence set `https://...` in `VITE_TITILER_API_BASE_URL`. Therefore, need to generate
self-signed certificate for TiTiler. Configuration details pending.

## Further configuration

Create local IP entries in your `/etc/hosts`

```
# Accelerator
xxx.xxx.xxx.xxx localip registry web_be
```

where `xxx.xxx.xxx.xxx` is your IP address on the IIASA network.

> [!NOTE]
> When changing the network environment, for example by taking a dev laptop home, you will need to change this.

## Startup the project

`docker compose -f docker-compose.dev.yml up [--build]`

## Browse

Browse to the backend at `https://localhost:8000/api/v1/`. In case of a security warning on account of the self-signed
certificate, add an exception in your browser.

Browse to the frontend at `https://localhost:8080/` or `https://localhost:8000/`. In case of a security warning on
account of the self-signed certificate, add an exception in your browser. Then log in via the `Login with IIASA` button.
