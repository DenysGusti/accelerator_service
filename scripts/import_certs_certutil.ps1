$ErrorActionPreference = "Stop"

# Ensure script is running with Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating process to Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    exit 0
}

$certsDir = Join-Path $PSScriptRoot "..\certs"

$devCaCert = Join-Path $certsDir "public.crt"
$prodS3Cert = Join-Path $certsDir "prod-s3-internal.crt"

$newThumbprint = $null
if (Test-Path $devCaCert) {
    $newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($devCaCert)
    $newThumbprint = $newCert.Thumbprint
}

# 1. Clean up outdated Accelerator certificates from LocalMachine and CurrentUser Root stores
$oldCerts = Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root -ErrorAction SilentlyContinue |
    Where-Object { ($_.Subject -like "*CN=Accelerator*" -or $_.Subject -like "*CN=IIASA Accelerator*") -and ($_.Thumbprint -ne $newThumbprint) }

foreach ($cert in $oldCerts) {
    Write-Host "Removing outdated cert '$($cert.Subject)' ($($cert.Thumbprint))..." -ForegroundColor Yellow
    certutil.exe -delstore root $cert.Thumbprint | Out-Null
    certutil.exe -user -delstore root $cert.Thumbprint | Out-Null
}

# 2. Import current Dev Root CA
if (Test-Path $devCaCert) {
    Write-Host "Importing Dev CA ($devCaCert)..." -ForegroundColor Cyan
    certutil.exe -addstore -f root $devCaCert
} else {
    Write-Warning "Dev CA cert not found at $devCaCert. Please generate certs/public.crt and certs/private.key first."
}

# 3. Import Prod Internal S3 CA
if (Test-Path $prodS3Cert) {
    Write-Host "Importing Prod Internal S3 CA ($prodS3Cert)..." -ForegroundColor Cyan
    certutil.exe -addstore -f root $prodS3Cert
}

Write-Host "`nCertificates successfully updated in Windows Root store!" -ForegroundColor Green
