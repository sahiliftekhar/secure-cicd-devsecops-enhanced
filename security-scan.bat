@echo off
echo Starting Container Security Scan...

REM Build Docker image
docker build -t secure-cicd-devsecops-enhanced:latest .

REM Create reports directory
if not exist "security-reports" mkdir security-reports

REM Run Trivy vulnerability scan
echo Running vulnerability scan...
trivy image --format table --severity HIGH,CRITICAL secure-cicd-devsecops-enhanced:latest > security-reports\vulnerability-report.txt

REM Run Trivy secret scan
echo Running secret detection...
trivy fs --scanners secret --format table . > security-reports\secret-report.txt

REM Run Hadolint using Docker (no installation needed)
echo Running Dockerfile analysis...
docker run --rm -i hadolint/hadolint < Dockerfile > security-reports\dockerfile-analysis.txt

echo Security scan completed!
echo Check security-reports folder for results.
pause