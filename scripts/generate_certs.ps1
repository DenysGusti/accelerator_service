[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$certsDir = Join-Path $PSScriptRoot "..\certs"
$caDir = Join-Path $certsDir "ca"
$minioDir = Join-Path $certsDir "minio"
$backendDir = Join-Path $certsDir "backend"

New-Item -ItemType Directory -Force -Path $caDir, $minioDir, $backendDir | Out-Null

$opensslExe = (Get-Command openssl.exe -ErrorAction SilentlyContinue).Source
if (-not $opensslExe) {
    $gitOpenssl = "C:\Users\gustid\AppData\Local\Programs\Git\usr\bin\openssl.exe"
    if (Test-Path $gitOpenssl) {
        $opensslExe = $gitOpenssl
    } else {
        $gitPath = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
        if ($gitPath) {
            $candidate = Join-Path (Split-Path (Split-Path $gitPath)) "usr\bin\openssl.exe"
            if (Test-Path $candidate) {
                $opensslExe = $candidate
            }
        }
    }
}

if (-not $opensslExe) {
    Write-Error "openssl was not found in PATH or Git installation."
    exit 1
}

Write-Host "=== Generating Unified Self-Signed Root CA & Server Certificate ===" -ForegroundColor Cyan

$san = "DNS:localhost,DNS:minio,DNS:web_be,DNS:web-be,DNS:localip,DNS:host.docker.internal,IP:127.0.0.1"
$extFile = Join-Path $certsDir "unified_ext.cnf"
$caKey = Join-Path $caDir "ca.key"
$caCrt = Join-Path $caDir "ca.crt"

@"
[v3]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyEncipherment,keyCertSign,cRLSign
extendedKeyUsage = serverAuth,clientAuth
subjectAltName = $san
"@ | Set-Content -Path $extFile -Encoding utf8

# 1. Generate key
& $opensslExe genrsa -out $caKey 2048

# 2. Generate self-signed cert
$env:MSYS_NO_PATHCONV = "1"
& $opensslExe req -new -x509 -days 1461 `
    -key $caKey `
    -out $caCrt `
    -subj "/CN=Accelerator-Dev-Root-CA" `
    -config $extFile `
    -extensions v3

Remove-Item -Force $extFile -ErrorAction SilentlyContinue

# 3. Propagate to MinIO and Backend mounts
Copy-Item -Force $caCrt (Join-Path $minioDir "public.crt")
Copy-Item -Force $caKey (Join-Path $minioDir "private.key")
Copy-Item -Force $caCrt (Join-Path $backendDir "public.crt")
Copy-Item -Force $caKey (Join-Path $backendDir "private.key")

Write-Host "=== Unified certificate successfully generated and deployed to certs/ ===" -ForegroundColor Green
