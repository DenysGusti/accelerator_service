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
`accelerator` topic under the IIASA Github organization](https://github.com/search?q=org%3Aiiasa%20topic%3Aaccelerator&type=repositories),
clone it somewhere convenient, and point `ACCMS_PROJECT_FOLDER` at the resulting working directory.

> [!CAUTION]
> Relative paths (relative to the `accelerator_service` working directory root) should start with `./` to avoid being
> mistaken for a volume name.

### `.env.web.be` (backend)

Aside from the self-explanatory settings...

Insert the IPv4 address of your dev machine in the value of `INITIAL_S3_ENDPOINT` before the port number.

Set `JOB_SECRET_ENCRYPTION_KEY` to the base64-encoded representation of random 256-bit key values which you can obtain
as follows:

```
head </dev/random -c32 | base64
```

This key encrypts secrets required by jobs.

Set `BUCKET_DETAILS_ENCRYPTION_KEY` to the base64-encoded representation of random 256-bit key values which you can
obtain as follows:

```
head </dev/random -c32 | base64
```

This key encrypts bucket credentials.

Need a public/private keypair. Tokens are signed with the private key by the backend, and can be verified with the
public key. This is useful for example for the gateway for interactive containers: the gateway simply verifies the token
via the public key as obtained via the `GET` method at
`https://accelerator-api.iiasa.ac.at/docs#/.well-known/jwks.json`.

Use OpenSSL to generate the keypair and extract the public key:

```
openssl ecparam -genkey -name prime256v1 -noout -out private_key.pem
openssl ec -in private_key.pem -pubout -out public_key.pem
```

Set the following:

```
JWT_BASE64_PRIVATE_KEY="$(base64 -w0 private_key.pem)"
JWT_BASE64_PUBLIC_KEY="$(base64 -w0 public_key.pem)"
```

### `.env.web.fe` (frontend)

Must use https with TiTiler and hence set `https://...` in `VITE_TITILER_API_BASE_URL`. Therefore need to generate
self-signed certificate for TiTiler. Configuration details pending. Query an LLM on how to obtain a self-signed
certificate that also works for `localhost`.

### `.env.scheduler` (job dispatcher)

In `.env.scheduler`, aside from the obvious settings:

1. In `.env.scheduler` configure `IMAGE_REGISTRY_*`. `IMAGE_REGISTRY_TAG_PREFIX` is needed when the registry is
   subdivided in namespaces. For example Harbor uses projects. If so, set the name of your space/project followed by a
   slash as value.
    - When the registry service is running, you should be able to login via  `docker login <registry>:8443` and the
      configured username and password.
2. Set `JOBSTORE_*` values to point to an S3 bucket for transient file storage when launching WKube jobs.
3. Convert `~/.kube/config` to JSON and then a base64 string:
   ```
   kubectl config view --output json --raw > kubeconfig.json
   ```
   Edit the JSON to remove irrelevant contexts / credentials.
   Change host name to `host.docker.internal` if you are using Docker Desktop with WSL
   ```
   base64 -w0 kubeconfig.json > kubeconfig.b64
   ```
   Set  `WKUBE_SECRET_JSON_B64` to the content of `kubeconfig.b64`.
    - Or use command
      `python3 -c "import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin), indent=2))" < ~/.kube/config > config.json`
      to convert the kubernetes config to JSON.
4. Set `ACCELERATOR_APP_TOKEN` by obtaining a token as follows:
    - Startup the backend service:  
      `docker compose up web_be`
        - This also starts the integrated frontend.
    - Create an account for yourself by signing in to the front end at `https://localhost:8080`.
        - Press the "Login with IIASA" button.
    - With `docker ps`, determine the container ID of the backend and shell into the container:  
      `docker ps | grep web_be`  
      `docker exec -it <backend container ID> /bin/bash`
    - Grant your account superuser rights:  
      `python apply.py add_role <your email> APP__SUPERUSER`
    - Obtain an access token with superuser rights:  
      `python apply.py get_access_token <your email> <seconds to expiry>`
    - Copy and paste the token as the value of `ACCELERATOR_APP_TOKEN`.
5. Set `USE_HOST_NAMESPACES` to `1` if you use WSL.
6. Apply the Kubernetes Local Bridge Manifest. If you are using Kubernetes in Docker Desktop:
    - Get current dynamic IPs of the local containers (be cautious if container names are the same).

      `export MINIO_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' accelerator_service-minio-1)`

      `export REGISTRY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' accelerator_service-registry-1)`

      `$MINIO_IP = (docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' accelerator_service-minio-1)`

      `$REGISTRY_IP = (docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' accelerator_service-registry-1)`

    - Inject the IPs into the template and apply directly to Kubernetes.
      `envsubst < k8s/manifests/k8s-local-setup.yaml | kubectl apply -f -`

      `(Get-Content -Path "k8s\manifests\k8s-local-setup.yaml" -Raw) -replace '\$\{MINIO_IP\}', $MINIO_IP -replace '\$\{REGISTRY_IP\}', $REGISTRY_IP | kubectl apply -f -`

### [TiTiler](https://developmentseed.org/titiler/) (tile server)

1. Clone the repo `https://github.com/iiasa/meta-titiler`
2. Point `TITILER_FOLDER` in `.env` at the resulting working directory.
3. Check that a certificate is present in `certs`. If absent, create a self-signed certificate expiring in `$DAYS` for
   TiTiler by issuing:
   ```
   cd meta-titiler
   mkdir certs
   cd certs
   openssl req -x509 -newkey rsa:2048 -keyout private.key -out public.crt -days $DAYS -nodes -subj "/CN=localip"
   cp public.crt ../dockerfiles/minio-cert.crt
   cd ..
   ```

### MinIO (block storage, S3)

1. Create a self-signed certificate:
   ```
   cd minio_certs
   openssl req -x509 -newkey rsa:2048 -keyout private.key -out public.crt -days $DAYS -nodes -subj "/CN=localhost"
   cd ..
   ```
   where `$DAYS` is the number of days before the certificate expires. Use a big number to effectively have no expiry.
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
7. In `.env.web.be` and `.env.scheduler`, set these as values of the `*_S3_API_KEY=` and `*_S3_SECRET_KEY=` entries.
8. Add the MinIO endpoint to your system's known hosts.

### Registry

Generate `htpasswd` file:

1. `docker pull httpd:2`
2. `docker run --rm --entrypoint htpasswd httpd:2 -Bbn myregistry myregistrypassword > registry_auth/htpasswd`

### Database

1. Execute `docker compose -f docker-compose.dev.yml up db [--build]` to start the service and optionally (re)build the
   image.
2. Enter the db container with `docker exec -it <db container ID> /bin/bash`
3. Create databases inside the container with:
    - `su -- postgres -c "createdb accelerator"`
    - `su -- postgres -c "createdb acceleratortest"`
    - `su -- postgres -c "createdb accms"`
    - `su -- postgres -c "createdb thrd"`
4. When a database already exists, you may wish to drop it first to start with a clean slate:
    - `su -- postgres -c "dropdb accelerator"`
    - `su -- postgres -c "dropdb acceleratortest"`
    - `su -- postgres -c "dropdb accms"`
    - `su -- postgres -c "dropdb thrd"`

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

Browse to the backend at `https://localhost:8000`. In case of a security warning on account of the self-signed
certificate, add an exception in your browser.

Browse to the frontend at `https://localhost:8080`. In case of a security warning on account of the self-signed
certificate, add an exception in your browser. Then log in via the `Login with IIASA` button.

## Additional notes

- Inside `control_services_backend` ignore the `.env.sample`, the configs are passed down as the containers are
  orchestrated.
