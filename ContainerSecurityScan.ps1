param(
  [string]$ImageName = "secure-cicd-devsecops-enhanced",
  [string]$ImageTag  = "latest"
)

$FullImage  = "$ImageName`:$ImageTag"
$ReportDir  = ".\security-reports"
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"

# Ensure report directory exists
if (!(Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir | Out-Null }

Write-Host "🔍 Starting Container Security Scan: $FullImage" -ForegroundColor Cyan

# Step 1: Trivy Vulnerability Scan
Write-Host "Step 1/4: Running Trivy vulnerability scan..." -ForegroundColor Yellow
trivy image `
  --format json `
  --output "$ReportDir\trivy-vulns-$Timestamp.json" `
  --severity HIGH,CRITICAL `
  $FullImage

trivy image `
  --format table `
  --output "$ReportDir\trivy-vulns-$Timestamp.txt" `
  --severity HIGH,CRITICAL `
  $FullImage

# Step 2: Trivy Secret Detection
Write-Host "Step 2/4: Running secret detection..." -ForegroundColor Yellow
trivy fs `
  --scanners secret `
  --format json `
  --output "$ReportDir\trivy-secrets-$Timestamp.json" `
  .\

# Step 3: Hadolint Dockerfile Analysis (using Docker container)
Write-Host "Step 3/4: Running Hadolint Dockerfile analysis..." -ForegroundColor Yellow
docker run --rm -i hadolint/hadolint `
  < Dockerfile `
  --format json `
  > "$ReportDir\hadolint-$Timestamp.json"

# Step 4: Summary and Gate
Write-Host "Step 4/4: Generating summary and evaluating gate..." -ForegroundColor Yellow

# Parse counts
$Critical = (Get-Content "$ReportDir\trivy-vulns-$Timestamp.json" | ConvertFrom-Json).Results |
  ForEach-Object { $_.Vulnerabilities } |
  Where-Object { $_.Severity -eq 'CRITICAL' } | Measure-Object | Select-Object -ExpandProperty Count
$Secrets  = (Get-Content "$ReportDir\trivy-secrets-$Timestamp.json" | ConvertFrom-Json).Results |
  ForEach-Object { $_.Secrets } | Measure-Object | Select-Object -ExpandProperty Count

Write-Host "🔴 Critical Vulnerabilities: $Critical"
Write-Host "🔒 Secrets Detected:      $Secrets"

if ($Critical -gt 0 -or $Secrets -gt 0) {
  Write-Host "❌ SECURITY GATE FAILED" -ForegroundColor Red
  exit 1
} else {
  Write-Host "✅ SECURITY GATE PASSED" -ForegroundColor Green
  exit 0
}
