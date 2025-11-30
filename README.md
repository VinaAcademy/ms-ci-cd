# VinaAcademy Microservices - Docker Swarm Deployment Guide

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Node Setup](#node-setup)
- [Environment Configuration](#environment-configuration)
- [Deployment](#deployment)
- [Management Commands](#management-commands)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides instructions for deploying the VinaAcademy microservices platform using Docker Swarm.

### Services Architecture

| Service | Description | Port |
|---------|-------------|------|
| eureka-server | Service Discovery | 8761 |
| api-gateway | API Gateway | 8080 |
| vinaacademy-platform | Main Platform Service | 8081, 9090 (gRPC) |
| notification-service | Email/Notification Service | 8082 |
| chat-service | Real-time Chat Service | 8083 |
| vinaacademy-frontend | Next.js Frontend | 3000 |
| redis | Cache & Session Store | 6379 |
| kafka | Message Broker | 9092, 29092 |

### External Services (Cloud)

- **PostgreSQL**: Cloud database (AWS RDS, Azure Database, Supabase, etc.)
- **MinIO/S3**: Cloud object storage (AWS S3, MinIO Cloud, Cloudflare R2, etc.)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Docker Swarm Cluster                          │
├─────────────────────────────────┬───────────────────────────────────┤
│     vina-tools (2GB RAM)        │   vina-microservices (8GB RAM)    │
│        role: tools              │      role: worker-service         │
├─────────────────────────────────┼───────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐      │  ┌─────────────┐  ┌─────────────┐ │
│  │  Redis  │  │  Kafka  │      │  │   Eureka    │  │ API Gateway │ │
│  │  :6379  │  │  :9092  │      │  │   :8761     │  │   :8080     │ │
│  └─────────┘  └─────────┘      │  └─────────────┘  └─────────────┘ │
│                                 │  ┌─────────────┐  ┌─────────────┐ │
│                                 │  │  Platform   │  │Notification │ │
│                                 │  │ :8081,:9090 │  │   :8082     │ │
│                                 │  └─────────────┘  └─────────────┘ │
│                                 │  ┌─────────────┐  ┌─────────────┐ │
│                                 │  │    Chat     │  │  Frontend   │ │
│                                 │  │   :8083     │  │   :3000     │ │
│                                 │  └─────────────┘  └─────────────┘ │
└─────────────────────────────────┴───────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              ┌──────────┐   ┌──────────┐   ┌──────────┐
              │PostgreSQL│   │  MinIO   │   │  Gmail   │
              │ (Cloud)  │   │ (Cloud)  │   │  SMTP    │
              └──────────┘   └──────────┘   └──────────┘
```

---

## Prerequisites

### Hardware Requirements

| Node | Hostname | RAM | Role |
|------|----------|-----|------|
| Manager | vina-tools | 2GB+ | tools |
| Worker | vina-microservices | 8GB+ | worker-service |

### Software Requirements

- Docker Engine 24.0+ on all nodes
- Docker Swarm initialized
- Network connectivity between nodes
- Access to external services (PostgreSQL, MinIO)

### Cloud Services Required

1. **PostgreSQL Database** with 3 databases:
   - `vinaacademy` - Main platform database
   - `vinaacademy_email` - Notification service database
   - `vinaacademy_chat` - Chat service database

2. **Object Storage** (S3-compatible):
   - MinIO, AWS S3, Cloudflare R2, etc.

---

## Node Setup

### Step 1: Initialize Docker Swarm (on manager node)

```bash
# On vina-tools (manager node)
docker swarm init --advertise-addr <MANAGER_IP>
```

### Step 2: Join Worker Node

```bash
# Get join token from manager
docker swarm join-token worker

# On vina-microservices (worker node)
docker swarm join --token <TOKEN> <MANAGER_IP>:2377
```

### Step 3: Verify Swarm Cluster

```bash
docker node ls
```

Expected output:
```
ID                            HOSTNAME             STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
p8bsnsnkg8h0ka1feci1fvhhm     vina-microservices   Ready     Active                          29.1.1
q980appr1y8lfbrqees4xkaq7 *   vina-tools           Ready     Active         Leader           29.1.1
```

### Step 4: Label Nodes for Placement

```bash
# Label the tools node
docker node update --label-add role=tools vina-tools

# Label the worker-service node
docker node update --label-add role=worker-service vina-microservices
```

### Step 5: Verify Labels

```bash
docker node inspect vina-tools --format '{{ .Spec.Labels }}'
docker node inspect vina-microservices --format '{{ .Spec.Labels }}'
```

---

## Environment Configuration

### Step 1: Create Environment File

Create a `.env` file in the project root with the following variables:

```bash
# =====================================================
# DATABASE CONFIGURATION (Cloud PostgreSQL)
# =====================================================
POSTGRES_URL=jdbc:postgresql://<HOST>:5432/vinaacademy
POSTGRES_NOTIFICATION_URL=jdbc:postgresql://<HOST>:5432/vinaacademy_email
POSTGRES_CHAT_HOST=<HOST>:5432
POSTGRES_CHAT_DB=vinaacademy_chat
POSTGRES_USERNAME=<USERNAME>
POSTGRES_PASSWORD=<PASSWORD>

# =====================================================
# OBJECT STORAGE (Cloud MinIO/S3)
# =====================================================
MINIO_ENDPOINT=https://<MINIO_HOST>
MINIO_ACCESS_KEY=<ACCESS_KEY>
MINIO_SECRET_KEY=<SECRET_KEY>

# =====================================================
# GOOGLE OAUTH
# =====================================================
GOOGLE_CLIENT_ID=<YOUR_GOOGLE_CLIENT_ID>
GOOGLE_CLIENT_SECRET=<YOUR_GOOGLE_CLIENT_SECRET>
GOOGLE_REDIRECT_URI=http://<YOUR_DOMAIN>/api/v1/auth/oauth2/callback/google

# =====================================================
# VNPAY PAYMENT
# =====================================================
VNPAY_TMN_CODE=<YOUR_VNPAY_TMN_CODE>
VNPAY_HASH_SECRET=<YOUR_VNPAY_HASH_SECRET>

# =====================================================
# EMAIL SERVICE
# =====================================================
GMAIL_USERNAME=<YOUR_GMAIL>
GMAIL_PASSWORD=<YOUR_APP_PASSWORD>

# =====================================================
# SECURITY
# =====================================================
APPLICATION_HMAC_SECRET=<YOUR_HMAC_SECRET>

# =====================================================
# FRONTEND
# =====================================================
NEXT_PUBLIC_API_URL=http://<YOUR_DOMAIN>:8080/api/v1
NEXT_PUBLIC_SITE_URL=http://<YOUR_DOMAIN>:3000
NEXT_PUBLIC_WS_URL=http://<YOUR_DOMAIN>:8080/ws
```

### Step 2: Prepare Config Files

Ensure the following config files exist:
```
app-config/dev/
├── api-gateway-dev.yml
├── chat-service-dev.yml
├── notification-service-dev.yml
└── vinaacademy-platform-dev.yml
```

### Step 3: Prepare Keys

Ensure RSA keys exist for JWT:
```
keys/
├── private_key.pem
└── public_key.pem
```

Generate if not exists:
```bash
# Generate private key
openssl genrsa -out keys/private_key.pem 2048

# Generate public key
openssl rsa -in keys/private_key.pem -pubout -out keys/public_key.pem
```

---

## Deployment

### Step 1: Copy Files to Manager Node

```bash
# Copy project files to manager node
scp -r . user@vina-tools:/path/to/vinaacademy/
```

### Step 2: Deploy Stack

> **⚠️ IMPORTANT**: Docker Stack does NOT automatically load `.env` files like Docker Compose!
> You must use one of the methods below.

**Method 1: Using Deploy Script (Recommended)**

```bash
# SSH to manager node
ssh user@vina-tools

# Navigate to project directory
cd /path/to/vinaacademy

# Make script executable (Linux/Mac)
chmod +x deploy.sh

# Run deploy script
./deploy.sh
```

For Windows PowerShell:
```powershell
# Run deploy script
.\deploy.ps1 -Action deploy
```

**Method 2: Manual Export Variables (Linux/Mac)**

```bash
# Export variables from .env file
export $(grep -v '^#' .env | grep -v '^$' | xargs)

# Deploy the stack
docker stack deploy -c docker-stack.yml vinaacademy
```

**Method 3: Using docker-compose config (Cross-platform)**

```bash
# Use docker-compose to substitute variables, then deploy
docker-compose -f docker-stack.yml config | docker stack deploy -c - vinaacademy
```

**Method 4: Manual Export Variables (Windows PowerShell)**

```powershell
# Load environment variables
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^#][^=]*)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

# Deploy the stack  
docker stack deploy -c docker-stack.yml vinaacademy
```

### Step 3: Verify Deployment

```bash
# Check all services
docker stack services vinaacademy

# Check service placement
docker stack ps vinaacademy

# Watch services starting
watch docker stack services vinaacademy
```

Expected output:
```
ID             NAME                             MODE         REPLICAS   IMAGE                                    PORTS
abc123         vinaacademy_redis                replicated   1/1        redis:7-alpine                           *:6379->6379/tcp
def456         vinaacademy_kafka                replicated   1/1        apache/kafka:3.9.1                       *:9092-9093->9092-9093/tcp
ghi789         vinaacademy_eureka-server        replicated   1/1        lochuung/eureka-server:latest            *:8761->8761/tcp
jkl012         vinaacademy_api-gateway          replicated   1/1        lochuung/api-gateway:latest              *:8080->8080/tcp
mno345         vinaacademy_vinaacademy-platform replicated   1/1        lochuung/vinaacademy-platform:latest     *:8081->8080/tcp
pqr678         vinaacademy_notification-service replicated   1/1        lochuung/notification-service:latest     *:8082->8080/tcp
stu901         vinaacademy_chat-service         replicated   1/1        lochuung/chat-service:latest             *:8083->8080/tcp
vwx234         vinaacademy_vinaacademy-frontend replicated   1/1        lochuung/vinaacademy-frontend:latest     *:3000->3000/tcp
```

---

## Management Commands

### View Services

```bash
# List all services
docker stack services vinaacademy

# List all tasks (containers)
docker stack ps vinaacademy

# List only running tasks
docker stack ps vinaacademy --filter "desired-state=running"
```

### View Logs

```bash
# View logs for a specific service
docker service logs vinaacademy_api-gateway

# Follow logs in real-time
docker service logs -f vinaacademy_vinaacademy-platform

# View last 100 lines
docker service logs --tail 100 vinaacademy_notification-service
```

### Scale Services

```bash
# Scale a service
docker service scale vinaacademy_api-gateway=2

# Scale multiple services
docker service scale vinaacademy_api-gateway=2 vinaacademy_vinaacademy-platform=2
```

### Update Services

```bash
# Update a service image
docker service update --image lochuung/api-gateway:v2.0 vinaacademy_api-gateway

# Force update (re-deploy)
docker service update --force vinaacademy_api-gateway
```

### Rolling Update (Full Stack)

```bash
# Update stack with new configuration
docker stack deploy -c docker-stack.yml vinaacademy
```

### Remove Stack

```bash
# Remove entire stack
docker stack rm vinaacademy

# Verify removal
docker stack ps vinaacademy
```

### Cleanup

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (CAUTION!)
docker volume prune

# Remove everything unused
docker system prune -a
```

---

## Troubleshooting

### Check Service Health

```bash
# Check if services are healthy
docker stack ps vinaacademy --format "table {{.Name}}\t{{.CurrentState}}\t{{.Error}}"

# Inspect a specific service
docker service inspect vinaacademy_api-gateway
```

### Common Issues

#### 1. Service Not Starting

```bash
# Check service logs
docker service logs vinaacademy_<service-name>

# Check task errors
docker stack ps vinaacademy --no-trunc
```

#### 2. Network Issues

```bash
# List networks
docker network ls

# Inspect overlay network
docker network inspect vinaacademy_vinaacademy-network
```

#### 3. Config/Secret Issues

```bash
# List configs
docker config ls

# List secrets
docker secret ls

# Inspect config
docker config inspect vinaacademy_api-gateway-config
```

#### 4. Resource Constraints

```bash
# Check node resources
docker node inspect vina-tools --format '{{ .Description.Resources }}'
docker node inspect vina-microservices --format '{{ .Description.Resources }}'
```

#### 5. Service Placement Issues

```bash
# Verify node labels
docker node inspect vina-tools --format '{{ .Spec.Labels }}'
docker node inspect vina-microservices --format '{{ .Spec.Labels }}'

# Check placement constraints in service
docker service inspect vinaacademy_api-gateway --format '{{ .Spec.TaskTemplate.Placement }}'
```

### Health Check Endpoints

| Service | Health Check URL |
|---------|-----------------|
| Eureka Server | http://<HOST>:8761/actuator/health |
| API Gateway | http://<HOST>:8080/actuator/health |
| Platform | http://<HOST>:8081/actuator/health |
| Notification | http://<HOST>:8082/actuator/health |
| Chat | http://<HOST>:8083/actuator/health |
| Frontend | http://<HOST>:3000 |

---

## Memory Allocation Summary

### vina-tools (2GB RAM)

| Service | Limit | Reserved |
|---------|-------|----------|
| Redis | 256M | 128M |
| Kafka | 768M | 512M |
| **Total** | **~1GB** | **~640M** |

### vina-microservices (8GB RAM)

| Service | Limit | Reserved |
|---------|-------|----------|
| Eureka Server | 512M | 256M |
| API Gateway | 768M | 384M |
| Platform | 2G | 1G |
| Notification | 1G | 512M |
| Chat | 1G | 512M |
| Frontend | 512M | 256M |
| **Total** | **~5.8GB** | **~2.9GB** |

---

## Quick Reference

```bash
# Deploy
docker stack deploy -c docker-stack.yml vinaacademy

# Status
docker stack services vinaacademy

# Logs
docker service logs -f vinaacademy_<service-name>

# Remove
docker stack rm vinaacademy
```

---

## Support

For issues and questions, please create an issue in the repository or contact the development team.
