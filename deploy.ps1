# =====================================================
# VINAACADEMY DOCKER SWARM DEPLOYMENT SCRIPT (Windows PowerShell)
# =====================================================
# This script loads environment variables from .env file
# and deploys the stack to Docker Swarm
# =====================================================

param(
    [string]$Action = "deploy",
    [string]$StackName = "vinaacademy"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env"
$StackFile = Join-Path $ScriptDir "docker-stack.yml"

function Write-ColorOutput($ForegroundColor, $Message) {
    Write-Host $Message -ForegroundColor $ForegroundColor
}

Write-ColorOutput Green "================================================"
Write-ColorOutput Green "   VINAACADEMY DOCKER SWARM DEPLOYMENT"
Write-ColorOutput Green "================================================"

# Check if .env file exists
if (-not (Test-Path $EnvFile)) {
    Write-ColorOutput Red "Error: .env file not found!"
    Write-ColorOutput Yellow "Please create .env file from .env.example:"
    Write-Host "  cp .env.example .env"
    Write-Host "  # Edit .env with your configuration"
    exit 1
}

# Check if docker-stack.yml exists
if (-not (Test-Path $StackFile)) {
    Write-ColorOutput Red "Error: docker-stack.yml not found!"
    exit 1
}

# Check if Docker Swarm is initialized
$swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}' 2>$null
if ($swarmStatus -ne "active") {
    Write-ColorOutput Red "Error: Docker Swarm is not initialized!"
    Write-ColorOutput Yellow "Initialize with: docker swarm init"
    exit 1
}

# Load environment variables from .env file
Write-ColorOutput Yellow "Loading environment variables from .env..."

Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^([^#][^=]*)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        # Remove quotes if present
        $value = $value -replace '^["'']|["'']$', ''
        [Environment]::SetEnvironmentVariable($name, $value, "Process")
        Write-Host "  Loaded: $name" -ForegroundColor DarkGray
    }
}

# Verify critical environment variables
$RequiredVars = @(
    "POSTGRES_URL",
    "POSTGRES_USERNAME",
    "POSTGRES_PASSWORD",
    "MINIO_ENDPOINT",
    "MINIO_ACCESS_KEY",
    "MINIO_SECRET_KEY",
    "APPLICATION_HMAC_SECRET"
)

$MissingVars = @()
foreach ($var in $RequiredVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ([string]::IsNullOrEmpty($value)) {
        $MissingVars += $var
    }
}

if ($MissingVars.Count -gt 0) {
    Write-ColorOutput Red "Error: Missing required environment variables:"
    foreach ($var in $MissingVars) {
        Write-Host "  - $var"
    }
    exit 1
}

Write-ColorOutput Green "✓ All required environment variables loaded"

# Check node labels
Write-ColorOutput Yellow "Checking node labels..."

$toolsNode = docker node ls --filter "node.label.role=tools" -q 2>$null
$serviceNode = docker node ls --filter "node.label.role=worker-service" -q 2>$null

if ([string]::IsNullOrEmpty($toolsNode)) {
    Write-ColorOutput Yellow "Warning: No node with 'role=tools' label found"
    Write-Host "  Add label with: docker node update --label-add role=tools <node-name>"
}

if ([string]::IsNullOrEmpty($serviceNode)) {
    Write-ColorOutput Yellow "Warning: No node with 'role=worker-service' label found"
    Write-Host "  Add label with: docker node update --label-add role=worker-service <node-name>"
}

switch ($Action) {
    "deploy" {
        Write-ColorOutput Yellow "Deploying stack '$StackName'..."
        
        # Use docker-compose to substitute environment variables, then deploy
        # This is the most reliable way to handle env vars in Docker Stack
        docker-compose -f $StackFile config 2>$null | docker stack deploy -c - $StackName --with-registry-auth
        
        Write-Host ""
        Write-ColorOutput Green "================================================"
        Write-ColorOutput Green "   DEPLOYMENT INITIATED SUCCESSFULLY!"
        Write-ColorOutput Green "================================================"
        Write-Host ""
        Write-ColorOutput Yellow "Useful commands:"
        Write-Host "  View services:    docker stack services $StackName"
        Write-Host "  View tasks:       docker stack ps $StackName"
        Write-Host "  View logs:        docker service logs ${StackName}_<service-name>"
        Write-Host "  Remove stack:     docker stack rm $StackName"
        Write-Host ""
        Write-ColorOutput Yellow "Waiting for services to start..."
        Start-Sleep -Seconds 5
        docker stack services $StackName
    }
    "remove" {
        Write-ColorOutput Yellow "Removing stack '$StackName'..."
        docker stack rm $StackName
        Write-ColorOutput Green "Stack removed successfully!"
    }
    "status" {
        Write-ColorOutput Yellow "Stack '$StackName' status:"
        docker stack services $StackName
        Write-Host ""
        docker stack ps $StackName --filter "desired-state=running"
    }
    default {
        Write-Host "Usage: .\deploy.ps1 [-Action <deploy|remove|status>] [-StackName <name>]"
        Write-Host ""
        Write-Host "Actions:"
        Write-Host "  deploy  - Deploy or update the stack (default)"
        Write-Host "  remove  - Remove the stack"
        Write-Host "  status  - Show stack status"
    }
}
