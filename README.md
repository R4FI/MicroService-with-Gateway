# Microservices API Gateway with Docker and Nginx

A complete microservices architecture with an API Gateway implementation using Docker, Docker Compose, and Nginx as a reverse proxy.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Connection Flow](#connection-flow)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Testing the API Gateway](#testing-the-api-gateway)
- [API Endpoints](#api-endpoints)
- [Docker Commands](#docker-commands)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This project demonstrates a microservices architecture with three independent services:

1. **User Management Service** (ASP.NET Core) - Manages user data
2. **Product Service** (ASP.NET Core) - Manages product catalog
3. **Order Service** (Spring Boot/Java) - Manages orders

All services are accessed through a **single entry point** (API Gateway) using **Nginx** as a reverse proxy, orchestrated with **Docker Compose**.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         CLIENT                               │
│                   (Browser, Postman, curl)                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ All requests go to
                            │ http://localhost:80
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    API GATEWAY (Nginx)                       │
│                  Container: api-gateway                      │
│                       Port: 80                               │
│                                                              │
│  Routes:                                                     │
│  • /users/*    → User Management Service                    │
│  • /products/* → Product Service                            │
│  • /orders/*   → Order Service                              │
└──────────┬─────────────────┬─────────────────┬─────────────┘
           │                 │                 │
           │  Docker Bridge Network: microservices-network
           │                 │                 │
           ▼                 ▼                 ▼
┌──────────────────┐ ┌──────────────┐ ┌─────────────────┐
│ User Management  │ │   Product    │ │  Order Service  │
│    Service       │ │   Service    │ │                 │
│                  │ │              │ │                 │
│ .NET Core 9      │ │ .NET Core 9  │ │  Spring Boot    │
│ Port: 5126       │ │ Port: 5171   │ │  Port: 5003     │
│ (Internal only)  │ │ (Internal)   │ │  (Internal)     │
└──────────────────┘ └──────────────┘ └─────────────────┘
```

---

## 🔗 Connection Flow: How Everything is Connected

### Step-by-Step Connection Process

#### 1️⃣ **Dockerfile → Docker Image**

Each service has a `Dockerfile` that defines how to build its Docker image.

**Example: ProductService/Dockerfile**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
# Build the .NET application
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:9.0
# Create runtime container
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "ProductService.dll"]
```

**Connection**: Dockerfile → `docker build` → Docker Image → Docker Container

---

#### 2️⃣ **Docker Compose → Orchestration**

`docker-compose.yml` connects all the pieces together:

```yaml
services:
  productservice:
    build:
      context: ./ProductService    # 👈 Points to Dockerfile location
      dockerfile: Dockerfile       # 👈 Uses this Dockerfile
    container_name: productservice
    expose:
      - "5171"                     # 👈 Opens port within Docker network
    networks:
      - microservices-network      # 👈 Connects to shared network
```

**Connection Flow**:
1. Docker Compose reads `docker-compose.yml`
2. Finds `build.context` (./ProductService)
3. Looks for `Dockerfile` in that directory
4. Builds the image using that Dockerfile
5. Creates a container named `productservice`
6. Connects it to `microservices-network`

---

#### 3️⃣ **Docker Network → Service Communication**

Docker creates a **bridge network** named `microservices-network`:

```yaml
networks:
  microservices-network:
    driver: bridge              # 👈 Creates isolated internal network
```

**How Services Find Each Other**:
- Docker has built-in **DNS resolution**
- Container name becomes the hostname
- `productservice` container → accessible as `productservice:5171`
- `usermanagementservice` container → accessible as `usermanagementservice:5126`

**Example**:
```
Nginx config: proxy_pass http://productservice:5171
                                 ↑
                        Docker resolves this name
                                 ↓
                        Container IP: 172.18.0.3
```

---

#### 4️⃣ **Nginx Configuration → Routing**

The `nginx.conf` file defines routing rules:

```nginx
# Define backend service location
upstream product_service {
    server productservice:5171;  # 👈 Docker DNS resolves container name
}

# Route requests based on URL path
server {
    listen 80;
    
    location /products/ {
        proxy_pass http://product_service/;  # 👈 Forward to backend
        proxy_set_header Host $host;         # 👈 Preserve headers
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Connection Flow**:
1. Client sends: `GET http://localhost/products/api/products`
2. Nginx receives request on port 80
3. Matches `/products/` location block
4. Proxies to `http://productservice:5171/api/products`
5. Docker network routes to Product Service container
6. Response flows back: Service → Nginx → Client

---

#### 5️⃣ **Dockerfile.gateway → Nginx Container**

The API Gateway uses a custom Dockerfile:

```dockerfile
FROM nginx:alpine                          # 👈 Base Nginx image
COPY nginx.conf /etc/nginx/nginx.conf     # 👈 Copy routing rules
EXPOSE 80                                 # 👈 Expose gateway port
```

**Connection in docker-compose.yml**:
```yaml
api-gateway:
  build:
    context: .                      # 👈 Root directory
    dockerfile: Dockerfile.gateway  # 👈 Use this Dockerfile
  ports:
    - "80:80"                       # 👈 Map host:container ports
  depends_on:                       # 👈 Wait for these services
    - usermanagementservice
    - productservice
    - orderservice
  networks:
    - microservices-network         # 👈 Join same network
```

---

### 🔄 Complete Request Flow with All Connections

```
1. CLIENT
   └─→ curl http://localhost/products/api/products
        │
        │ (Request hits host machine port 80)
        ▼

2. DOCKER PORT MAPPING (Host → Container)
   └─→ localhost:80 maps to api-gateway:80
        │
        │ (Docker forwards to API Gateway container)
        ▼

3. API GATEWAY CONTAINER (Nginx)
   └─→ Nginx receives request
        │
        │ (Reads nginx.conf)
        ▼

4. NGINX ROUTING (nginx.conf)
   └─→ Matches location /products/
   └─→ Looks up upstream product_service
        │
        │ (Nginx needs to find "productservice" host)
        ▼

5. DOCKER DNS RESOLUTION
   └─→ Query: Where is "productservice"?
   └─→ Docker DNS: productservice = 172.18.0.3:5171
        │
        │ (Docker resolves container name to IP)
        ▼

6. DOCKER NETWORK (microservices-network)
   └─→ Routes request through bridge network
        │
        │ (Internal network communication)
        ▼

7. PRODUCT SERVICE CONTAINER
   └─→ Receives: GET /api/products
   └─→ .NET Core app processes request
   └─→ Queries MongoDB
   └─→ Returns JSON response
        │
        │ (Response ready)
        ▼

8. REVERSE FLOW
   └─→ Product Service → Docker Network
   └─→ Docker Network → Nginx Container
   └─→ Nginx → Port Mapping
   └─→ Port Mapping → Client
        │
        ▼

9. CLIENT RECEIVES RESPONSE
   └─→ HTTP 200 OK
   └─→ JSON: [{"id":"123","name":"Laptop","price":999.99}]
```

---

## 📦 Prerequisites

Before you begin, ensure you have the following installed:

- **Docker Desktop** (version 20.10 or higher)
  - Download: https://www.docker.com/products/docker-desktop
- **Docker Compose** (usually included with Docker Desktop)
- **curl** (for testing APIs) or **Postman**

### Verify Installation

```bash
# Check Docker version
docker --version
# Expected output: Docker version 20.10.x or higher

# Check Docker Compose version
docker-compose --version
# Expected output: Docker Compose version 2.x.x or higher

# Verify Docker is running
docker ps
# Should show list of containers (may be empty)
```

---

## 📂 Project Structure

```
MicroService-with-Gateway/
│
├── docker-compose.yml              # Orchestrates all services
├── Dockerfile.gateway              # API Gateway container definition
├── nginx.conf                      # Nginx routing configuration
├── .dockerignore                   # Excludes files from Docker builds
├── README.md                       # This file
├── README-GATEWAY.md               # Detailed gateway documentation
├── ARCHITECTURE.md                 # Architecture deep dive
├── start-gateway.sh                # Automated startup script
├── test-gateway.sh                 # Automated testing script
│
├── UserManagementService/
│   ├── Dockerfile                  # User service container
│   ├── UserManagementService.csproj
│   ├── Program.cs
│   ├── appsettings.json
│   ├── controller/
│   ├── data/
│   └── models/
│
├── ProductService/
│   ├── Dockerfile                  # Product service container
│   ├── ProductService.csproj
│   ├── Program.cs
│   ├── appsettings.json
│   ├── Controllers/
│   ├── Data/
│   ├── Models/
│   └── Services/
│
└── orderservice/
    ├── Dockerfile                  # Order service container
    ├── pom.xml
    ├── src/
    │   └── main/
    │       ├── java/
    │       └── resources/
    │           └── application.properties
    └── target/
```

---

## 🚀 Setup Instructions

### Step 1: Clone or Navigate to Project

```bash
cd /Users/rafi/MicroService-with-Gateway
```

### Step 2: Review Configuration Files (Optional)

Check the key files to understand the setup:

```bash
# View Docker Compose configuration
cat docker-compose.yml

# View Nginx routing rules
cat nginx.conf

# View API Gateway Dockerfile
cat Dockerfile.gateway
```

### Step 3: Build All Docker Images

This command builds Docker images for all four services (gateway + 3 microservices):

```bash
docker-compose build
```

**What happens**:
- Reads `docker-compose.yml`
- Builds `api-gateway` using `Dockerfile.gateway`
- Builds `usermanagementservice` using `UserManagementService/Dockerfile`
- Builds `productservice` using `ProductService/Dockerfile`
- Builds `orderservice` using `orderservice/Dockerfile`

**Expected output**:
```
[+] Building 45.2s (32/32) FINISHED
 => [usermanagementservice] ...
 => [productservice] ...
 => [orderservice] ...
 => [api-gateway] ...
```

### Step 4: Start All Services

Start all containers in detached mode (runs in background):

```bash
docker-compose up -d
```

**What happens**:
1. Creates Docker network: `microservices-network`
2. Starts all four containers
3. Connects them to the network
4. Maps port 80 to the host

**Expected output**:
```
[+] Running 5/5
 ✔ Network microservice-with-gateway_microservices-network  Created
 ✔ Container usermanagementservice                           Started
 ✔ Container productservice                                  Started
 ✔ Container orderservice                                    Started
 ✔ Container api-gateway                                     Started
```

### Step 5: Verify All Services Are Running

```bash
docker-compose ps
```

**Expected output**:
```
NAME                    STATUS         PORTS
api-gateway             Up 30 seconds  0.0.0.0:80->80/tcp
orderservice            Up 30 seconds  5003/tcp
productservice          Up 30 seconds  5171/tcp
usermanagementservice   Up 30 seconds  5126/tcp
```

All services should show **"Up"** status.

### Step 6: Check Service Logs (Optional)

View logs to ensure services started correctly:

```bash
# View all logs
docker-compose logs

# View logs for specific service
docker-compose logs api-gateway
docker-compose logs productservice
docker-compose logs usermanagementservice
docker-compose logs orderservice

# Follow logs in real-time
docker-compose logs -f
```

---

## ✅ Testing the API Gateway

### Quick Health Check

```bash
# Test gateway health
curl http://localhost/health
```

**Expected output**:
```
API Gateway is healthy
```

### Test Gateway Info

```bash
# Get available endpoints
curl http://localhost/
```

**Expected output**:
```json
{
  "message": "API Gateway",
  "endpoints": {
    "/users": "User Management Service",
    "/products": "Product Service",
    "/orders": "Order Service",
    "/health": "Gateway Health Check"
  }
}
```

### Test Each Microservice

#### 1. User Management Service

```bash
# Get all users
curl http://localhost/users/api/users

# Get single user (replace {id} with actual ID)
curl http://localhost/users/api/users/{id}

# Create a new user
curl -X POST http://localhost/users/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "John Doe",
    "email": "john.doe@example.com",
    "role": "Customer"
  }'
```

#### 2. Product Service

```bash
# Get all products
curl http://localhost/products/api/products

# Get single product (replace {id} with actual ID)
curl http://localhost/products/api/products/{id}

# Create a new product
curl -X POST http://localhost/products/api/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gaming Laptop",
    "price": 1299.99,
    "description": "High-performance gaming laptop"
  }'
```

#### 3. Order Service

```bash
# Get all orders
curl http://localhost/orders/api/orders

# Get single order (replace {id} with actual ID)
curl http://localhost/orders/api/orders/{id}

# Create a new order
curl -X POST http://localhost/orders/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "productId": "prod456",
    "quantity": 2,
    "totalAmount": 2599.98
  }'
```

### Automated Testing Script

Use the provided test script:

```bash
# Make script executable (first time only)
chmod +x test-gateway.sh

# Run tests
./test-gateway.sh
```

---

## 📍 API Endpoints

### Base URL

All requests go through: **`http://localhost`**

### Available Endpoints

| Service | Method | Endpoint | Description |
|---------|--------|----------|-------------|
| **Gateway** | GET | `/` | Gateway information |
| **Gateway** | GET | `/health` | Health check |
| **Users** | GET | `/users/api/users` | Get all users |
| **Users** | GET | `/users/api/users/{id}` | Get user by ID |
| **Users** | POST | `/users/api/users` | Create new user |
| **Users** | PUT | `/users/api/users/{id}` | Update user |
| **Users** | DELETE | `/users/api/users/{id}` | Delete user |
| **Products** | GET | `/products/api/products` | Get all products |
| **Products** | GET | `/products/api/products/{id}` | Get product by ID |
| **Products** | POST | `/products/api/products` | Create new product |
| **Products** | PUT | `/products/api/products/{id}` | Update product |
| **Products** | DELETE | `/products/api/products/{id}` | Delete product |
| **Orders** | GET | `/orders/api/orders` | Get all orders |
| **Orders** | GET | `/orders/api/orders/{id}` | Get order by ID |
| **Orders** | POST | `/orders/api/orders` | Create new order |
| **Orders** | PUT | `/orders/api/orders/{id}` | Update order |
| **Orders** | DELETE | `/orders/api/orders/{id}` | Delete order |

---

## 🐳 Docker Commands Reference

### Starting Services

```bash
# Build and start all services
docker-compose up --build

# Start in detached mode (background)
docker-compose up -d

# Build without cache
docker-compose build --no-cache

# Start specific service
docker-compose up productservice
```

### Stopping Services

```bash
# Stop all services (containers remain)
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop and remove containers, networks, and volumes
docker-compose down -v

# Stop specific service
docker-compose stop productservice
```

### Viewing Logs

```bash
# View all logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# View logs for specific service
docker-compose logs api-gateway
docker-compose logs productservice

# View last 100 lines
docker-compose logs --tail=100
```

### Managing Containers

```bash
# List running containers
docker-compose ps

# List all containers (including stopped)
docker ps -a

# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart productservice

# Execute command in running container
docker-compose exec productservice bash
docker-compose exec api-gateway sh
```

### Rebuilding Services

```bash
# Rebuild all services
docker-compose build

# Rebuild specific service
docker-compose build productservice

# Rebuild and restart
docker-compose up --build -d
```

### Cleaning Up

```bash
# Remove stopped containers
docker-compose rm

# Remove all unused images
docker image prune -a

# Remove all unused volumes
docker volume prune

# Complete cleanup (CAUTION: removes everything)
docker system prune -a --volumes
```

### Inspecting Network

```bash
# List Docker networks
docker network ls

# Inspect microservices network
docker network inspect microservice-with-gateway_microservices-network

# See which containers are connected
docker network inspect microservice-with-gateway_microservices-network | grep Name
```

---

## 🔧 Troubleshooting

### Issue 1: Port 80 Already in Use

**Error**: `Bind for 0.0.0.0:80 failed: port is already allocated`

**Solution**: Change the port in `docker-compose.yml`:

```yaml
api-gateway:
  ports:
    - "8080:80"  # Change to 8080 or any available port
```

Then access via `http://localhost:8080`

---

### Issue 2: Services Not Starting

**Check container status**:
```bash
docker-compose ps
```

**View error logs**:
```bash
docker-compose logs [service-name]
```

**Common causes**:
- Missing MongoDB connection
- Port conflicts
- Build errors

**Solution**: Rebuild from scratch:
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

---

### Issue 3: Gateway Returns 502 Bad Gateway

**Meaning**: Gateway can't reach backend service

**Check**:
```bash
# Verify all services are running
docker-compose ps

# Check gateway logs
docker-compose logs api-gateway

# Check backend service logs
docker-compose logs productservice
```

**Solution**:
```bash
# Restart the failing service
docker-compose restart productservice

# Or restart all services
docker-compose restart
```

---

### Issue 4: Docker Daemon Not Running

**Error**: `Cannot connect to the Docker daemon`

**Solution**:
- Start Docker Desktop application
- Wait for Docker to fully start
- Verify: `docker ps`

---

### Issue 5: Build Fails

**Solution**: Clean build cache and rebuild:
```bash
# Remove all build cache
docker builder prune -a

# Rebuild without cache
docker-compose build --no-cache

# Start services
docker-compose up -d
```

---

### Issue 6: Network Issues Between Containers

**Check network exists**:
```bash
docker network ls | grep microservices
```

**Recreate network**:
```bash
docker-compose down
docker-compose up -d
```

**Test connectivity**:
```bash
# Execute shell in gateway container
docker-compose exec api-gateway sh

# Try to ping backend service (inside container)
ping productservice
# Should resolve to internal IP
```

---

## 📚 Additional Resources

- **Detailed Architecture**: See `ARCHITECTURE.md`
- **Gateway Guide**: See `README-GATEWAY.md`
- **Docker Documentation**: https://docs.docker.com/
- **Nginx Documentation**: https://nginx.org/en/docs/

---

## 🎯 Quick Start Script

For convenience, use the automated script:

```bash
# Make script executable
chmod +x start-gateway.sh

# Run the script
./start-gateway.sh
```

This script will:
1. ✅ Check Docker is running
2. ✅ Stop existing containers
3. ✅ Build all images
4. ✅ Start all services
5. ✅ Wait for services to be ready
6. ✅ Display access information

---

## 🛑 Stopping Everything

When you're done:

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

---

## 📊 Monitoring

### Real-time Resource Usage

```bash
# View CPU, memory usage
docker stats
```

### Check Individual Container

```bash
# Inspect container details
docker inspect api-gateway
docker inspect productservice
```

---

## 🔐 Security Notes

**Current Setup (Development)**:
- ⚠️ All services use HTTP (not HTTPS)
- ⚠️ No authentication/authorization
- ⚠️ MongoDB credentials in plain text

**For Production**:
- ✅ Add SSL/TLS certificates
- ✅ Implement JWT authentication
- ✅ Use environment variables for secrets
- ✅ Add rate limiting
- ✅ Implement API keys

---

## 📝 Summary

This project demonstrates:
- ✅ Microservices architecture with polyglot services (.NET + Java)
- ✅ API Gateway pattern using Nginx
- ✅ Docker containerization
- ✅ Docker Compose orchestration
- ✅ Service-to-service communication via Docker networking
- ✅ Single entry point for all APIs

**Access Everything via**: `http://localhost`

---

## 🤝 Contributing

To add a new microservice:

1. Create service directory with Dockerfile
2. Add service to `docker-compose.yml`
3. Add routing rule in `nginx.conf`
4. Rebuild and restart

---

## 📧 Support

For issues or questions:
1. Check logs: `docker-compose logs -f`
2. Review `ARCHITECTURE.md` for details
3. Verify Docker is running: `docker ps`

---

**Made with ❤️ using Docker, Nginx, ASP.NET Core, and Spring Boot**
