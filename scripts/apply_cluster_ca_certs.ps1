[CmdletBinding()]
param (
    [string[]]$Namespaces = @("wkube", "kube-system")
)

$ErrorActionPreference = "Stop"

$certsDir = Join-Path $PSScriptRoot "..\certs"
$devCa = Join-Path $certsDir "ca\ca.crt"
$prodS3 = Join-Path $certsDir "prod-s3-internal.crt"

if (-not (Test-Path $devCa)) {
    Write-Error "Dev CA cert not found at $devCa. Run generate_certs.sh first."
    exit 1
}

# Ensure Kind cluster node is connected to the Docker Compose network (for minio/backend resolution)
try {
    $node = "desktop-control-plane"
    $net = "accelerator_service_default"
    $nodeInspect = docker inspect $node 2>$null | ConvertFrom-Json
    if ($nodeInspect -and (-not $nodeInspect[0].NetworkSettings.Networks.$net)) {
        Write-Host "Connecting cluster node $node to Docker network $net..." -ForegroundColor Cyan
        docker network connect $net $node 2>$null
    }
} catch {
    # Non-fatal if running outside local docker/kind
}

foreach ($ns in $Namespaces) {
    Write-Host "Creating cluster-ca-certs ConfigMap in namespace '$ns' from $certsDir..." -ForegroundColor Cyan

    $args = @(
        "create", "configmap", "cluster-ca-certs",
        "--from-file=accelerator-dev-ca.crt=$devCa"
    )

    if (Test-Path $prodS3) {
        $args += "--from-file=prod-s3-internal.crt=$prodS3"
    }

    $args += @("-n", $ns, "--dry-run=client", "-o", "yaml")

    $yaml = & kubectl @args
    $yaml | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to apply ConfigMap cluster-ca-certs in namespace '$ns'."
        exit $LASTEXITCODE
    }

    Write-Host "ConfigMap cluster-ca-certs successfully applied in namespace '$ns'." -ForegroundColor Green
}
