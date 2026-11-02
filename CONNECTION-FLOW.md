# Connection Flow: Dockerfile → Docker Compose → Nginx

This document explains **exactly how all components are connected** in the API Gateway architecture.

---

## 🔗 Complete Connection Chain

```
📄 Dockerfile → 🏗️ Docker Image → 📦 Docker Container → 🌐 Docker Network → 🚪 Nginx Gateway → 👤 Client
```

---

## 1️⃣ Dockerfile → Docker Image

### What is a Dockerfile?

A **Dockerfile** is a text file with instructions to build a Docker image.

### Example: ProductService/Dockerfile

```dockerfile
# Start from base .NET image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set working directory
WORKDIR /src

# Copy and restore dependencies
COPY ProductService.csproj .
RUN dotnet restore

# Copy source code and build
COPY . .
RUN dotnet publish -c Release -o /app

# Create runtime image
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app .

# Define how to start the application
ENTRYPOINT ["dotnet", "ProductService.dll"]
```

### Connection Process:

```
1. Dockerfile (ProductService/Dockerfile)
   ↓
2. docker build command reads Dockerfile
   ↓
3. Executes each instruction (FROM, COPY, RUN, etc.)
   ↓
4. Creates layers (each instruction = new layer)
   ↓
5. Final result: Docker Image (productservice:latest)
```

### Command:

```bash
# Manual build (usually not needed)
docker build -t productservice:latest ./ProductService
```

---

## 2️⃣ Docker Compose → Orchestration

### What is Docker Compose?

**Docker Compose** orchestrates multiple containers, defining how they should be built and connected.

### docker-compose.yml Structure:

```yaml
version: '3.8'

services:
  # Service 1: Product Service
  productservice:
    build:
      context: ./ProductService    # 📂 Directory containing Dockerfile
      dockerfile: Dockerfile       # 📄 Dockerfile name
    container_name: productservice # 🏷️ Container name
    expose:
      - "5171"                     # 🔓 Open port in Docker network
    networks:
      - microservices-network      # 🌐 Connect to this network

  # Service 2: API Gateway
  api-gateway:
    build:
      context: .                   # 📂 Root directory
      dockerfile: Dockerfile.gateway # 📄 Use this Dockerfile
    ports:
      - "80:80"                    # 🚪 Map host:container ports
    depends_on:
      - productservice             # ⏳ Wait for this service
    networks:
      - microservices-network      # 🌐 Same network

networks:
  microservices-network:           # 🌐 Define shared network
    driver: bridge
```

### Connection Process:

```
1. You run: docker-compose up
   ↓
2. Docker Compose reads docker-compose.yml
   ↓
3. For each service:
   ├─ Finds build.context directory
   ├─ Looks for build.dockerfile
   ├─ Runs docker build in that context
   ├─ Creates Docker image
   └─ Creates Docker container from image
   ↓
4. Creates network: microservices-network
   ↓
5. Connects all containers to the network
   ↓
6. Applies port mappings (host → container)
   ↓
7. Starts containers in dependency order
```

---

## 3️⃣ Docker Network → Service Discovery

### What is Docker Network?

A **Docker Network** is a virtual network that allows containers to communicate with each other.

### How It Works:

```yaml
networks:
  microservices-network:
    driver: bridge              # Creates isolated network bridge
```

### Connection Details:

```
┌─────────────────────────────────────────────────────┐
│         Docker Network: microservices-network       │
│              (Bridge Network: 172.18.0.0/16)        │
│                                                     │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │  api-gateway     │  │  productservice  │       │
│  │  IP: 172.18.0.2  │  │  IP: 172.18.0.3  │       │
│  │  Port: 80        │  │  Port: 5171      │       │
│  └──────────────────┘  └──────────────────┘       │
│                                                     │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │ usermanagement   │  │  orderservice    │       │
│  │ IP: 172.18.0.4   │  │  IP: 172.18.0.5  │       │
│  │ Port: 5126       │  │  Port: 5003      │       │
│  └──────────────────┘  └──────────────────┘       │
└─────────────────────────────────────────────────────┘
```

### Docker DNS Resolution:

Docker provides automatic DNS that resolves container names to IPs:

```
Container Name → Docker DNS → Internal IP
──────────────────────────────────────────
productservice → resolves to → 172.18.0.3
usermanagementservice → resolves to → 172.18.0.4
orderservice → resolves to → 172.18.0.5
```

### Example:

When Nginx config says:
```nginx
server productservice:5171;
```

Docker automatically translates this to:
```
server 172.18.0.3:5171;
```

---

## 4️⃣ Nginx Configuration → Request Routing

### nginx.conf Structure:

```nginx
# Define backend services (upstream blocks)
upstream product_service {
    server productservice:5171;  # Container name:port
}

upstream user_service {
    server usermanagementservice:5126;
}

upstream order_service {
    server orderservice:5003;
}

# Define routing rules (server block)
server {
    listen 80;  # Listen on port 80

    # Route /products/* to product service
    location /products/ {
        proxy_pass http://product_service/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Route /users/* to user service
    location /users/ {
        proxy_pass http://user_service/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Route /orders/* to order service
    location /orders/ {
        proxy_pass http://order_service/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### How Nginx Connects to Backend Services:

```
1. Nginx reads nginx.conf at startup
   ↓
2. Sees: upstream product_service { server productservice:5171; }
   ↓
3. Needs to resolve "productservice" hostname
   ↓
4. Asks Docker DNS: "Where is productservice?"
   ↓
5. Docker DNS responds: "172.18.0.3"
   ↓
6. Nginx stores: product_service = 172.18.0.3:5171
   ↓
7. When request comes to /products/...
   ↓
8. Nginx forwards to 172.18.0.3:5171
```

---

## 5️⃣ Port Mapping → External Access

### Host to Container Mapping:

```yaml
api-gateway:
  ports:
    - "80:80"    # host_port:container_port
```

### What This Means:

```
┌─────────────────────┐
│    Host Machine     │
│   (Your Computer)   │
│                     │
│   localhost:80 ─────┼─────┐
└─────────────────────┘     │
                            │ Docker maps this port
                            │
                            ↓
┌─────────────────────────────────────┐
│         Docker Engine               │
│                                     │
│  ┌───────────────────────────┐     │
│  │  api-gateway container    │     │
│  │  Port 80 (inside)         │←────┘
│  └───────────────────────────┘     │
└─────────────────────────────────────┘
```

### Why Backend Services Don't Need Port Mapping:

```yaml
productservice:
  expose:
    - "5171"    # Only accessible within Docker network
  # NO ports: section = NOT accessible from host
```

**Reason**: Security! Backend services should only be accessible through the gateway.

---

## 🔄 Complete Request Flow with All Connections

### Example: Client requests product list

```
STEP 1: CLIENT INITIATES REQUEST
────────────────────────────────
Client runs: curl http://localhost/products/api/products

┌──────────┐
│  Client  │
└────┬─────┘
     │ HTTP GET /products/api/products
     ▼


STEP 2: HOST PORT MAPPING
──────────────────────────
localhost:80 (host) maps to api-gateway:80 (container)

┌────────────────────┐
│   Host Machine     │
│   localhost:80     │
└─────────┬──────────┘
          │ Port mapping: 80:80
          ▼
┌────────────────────┐
│ Docker Port Map    │
└─────────┬──────────┘
          │
          ▼


STEP 3: API GATEWAY CONTAINER RECEIVES REQUEST
───────────────────────────────────────────────
Request arrives at Nginx inside api-gateway container

┌─────────────────────────────────┐
│  api-gateway container          │
│  IP: 172.18.0.2:80              │
│  ┌───────────────────────┐      │
│  │  Nginx Process        │      │
│  │  Reads nginx.conf     │      │
│  └───────────────────────┘      │
└─────────────────────────────────┘
          │
          │ Matches location /products/
          ▼


STEP 4: NGINX ROUTING DECISION
───────────────────────────────
Nginx looks up upstream: product_service

nginx.conf says:
  location /products/ {
      proxy_pass http://product_service/;
  }

upstream product_service {
    server productservice:5171;
}

Nginx needs to find: productservice:5171
          │
          ▼


STEP 5: DOCKER DNS RESOLUTION
──────────────────────────────
Docker DNS resolves container name to IP

Request: Where is "productservice"?
Response: 172.18.0.3

┌──────────────────────────┐
│     Docker DNS           │
│  productservice →        │
│     172.18.0.3           │
└────────────┬─────────────┘
             │
             ▼


STEP 6: DOCKER NETWORK ROUTING
───────────────────────────────
Request travels through microservices-network

┌───────────────────────────────────────┐
│  Docker Network: microservices-network│
│  (Internal Bridge Network)            │
│                                       │
│  172.18.0.2:80 ──────→ 172.18.0.3:5171│
│  (gateway)              (product)     │
└───────────────────────────────────────┘
             │
             ▼


STEP 7: PRODUCT SERVICE RECEIVES REQUEST
─────────────────────────────────────────
Request arrives at productservice container

┌─────────────────────────────────────┐
│  productservice container           │
│  IP: 172.18.0.3:5171                │
│  ┌───────────────────────────┐      │
│  │  .NET Core Application    │      │
│  │  Receives: GET /api/products │   │
│  │  (Note: /products/ removed)  │   │
│  └───────────────────────────┘      │
└─────────────────────────────────────┘
          │
          │ Processes request
          │ Queries MongoDB
          │ Builds JSON response
          ▼


STEP 8: RESPONSE FLOWS BACK
────────────────────────────

┌─────────────────────────────────────┐
│  productservice:5171                │
│  Returns: HTTP 200 OK               │
│  Body: [{"id":"1","name":"Laptop"}] │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Docker Network                     │
│  Routes response back               │
│  172.18.0.3 → 172.18.0.2            │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  api-gateway:80 (Nginx)             │
│  Receives response from backend     │
│  Adds headers, logs request         │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Docker Port Mapping                │
│  Container port 80 → Host port 80   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Client receives response           │
│  HTTP 200 OK                        │
│  [{"id":"1","name":"Laptop"}]       │
└─────────────────────────────────────┘
```

---

## 🎯 Key Connection Points Summary

| Component | Connects To | How | Why |
|-----------|-------------|-----|-----|
| **Dockerfile** | Docker Image | `docker build` command | Defines how to build the image |
| **Docker Compose** | Dockerfile | `build.context` + `build.dockerfile` | Tells Docker which Dockerfile to use |
| **Docker Image** | Docker Container | `docker run` (via compose) | Container is a running instance of an image |
| **Docker Container** | Docker Network | `networks:` section in compose | Allows containers to communicate |
| **Docker Network** | Other Containers | Docker DNS (bridge driver) | Resolves container names to IPs |
| **Nginx Config** | Backend Services | Container names in upstream blocks | Routes requests to the right service |
| **Host Port** | Container Port | `ports:` section in compose | Makes gateway accessible from outside |
| **Client** | API Gateway | HTTP requests to localhost:80 | Single entry point for all APIs |

---

## 📊 Visual Connection Map

```
┌─────────────────────────────────────────────────────────────────┐
│                     DOCKER COMPOSE                              │
│                   (docker-compose.yml)                          │
│                                                                 │
│  Reads configuration for 4 services:                            │
│  ├─ api-gateway (./Dockerfile.gateway)                          │
│  ├─ productservice (./ProductService/Dockerfile)                │
│  ├─ usermanagementservice (./UserManagementService/Dockerfile)  │
│  └─ orderservice (./orderservice/Dockerfile)                    │
└─────────────┬───────────────────────────────────────────────────┘
              │
              │ Builds images and creates containers
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    DOCKER ENGINE                                │
│                                                                 │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐    │
│  │ Image:       │  │ Image:        │  │ Image:           │    │
│  │ api-gateway  │  │ productservice│  │ usermanagement   │    │
│  └──────┬───────┘  └───────┬───────┘  └────────┬─────────┘    │
│         │                  │                     │              │
│         └──────────────────┴─────────────────────┘              │
│                            │                                    │
│                   Creates containers                            │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         DOCKER NETWORK: microservices-network            │  │
│  │         (Bridge: 172.18.0.0/16)                          │  │
│  │                                                          │  │
│  │  ┌────────────┐ ┌─────────────┐ ┌──────────────────┐   │  │
│  │  │ gateway    │ │ product     │ │ usermanagement   │   │  │
│  │  │ :80        │ │ :5171       │ │ :5126            │   │  │
│  │  └─────┬──────┘ └──────┬──────┘ └────────┬─────────┘   │  │
│  │        │               │                  │             │  │
│  │        │  Docker DNS resolves names       │             │  │
│  │        │  productservice → 172.18.0.3     │             │  │
│  │        │               │                  │             │  │
│  │        └───────────────┴──────────────────┘             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
              │
              │ Port mapping: 80:80
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        HOST MACHINE                             │
│                      localhost:80                               │
│                           ▲                                     │
│                           │                                     │
│                      Client access                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Verification Commands

Test each connection point:

### 1. Check Dockerfiles Exist

```bash
ls -la ProductService/Dockerfile
ls -la UserManagementService/Dockerfile
ls -la orderservice/Dockerfile
ls -la Dockerfile.gateway
```

### 2. Check Docker Compose Configuration

```bash
docker-compose config
```

### 3. Check Docker Images

```bash
docker images | grep microservice
```

### 4. Check Running Containers

```bash
docker-compose ps
```

### 5. Check Docker Network

```bash
docker network ls | grep microservices
docker network inspect microservice-with-gateway_microservices-network
```

### 6. Test DNS Resolution

```bash
# Enter gateway container
docker-compose exec api-gateway sh

# Try to resolve backend services
nslookup productservice
ping -c 2 productservice
```

### 7. Test Nginx Configuration

```bash
# Check Nginx config syntax
docker-compose exec api-gateway nginx -t

# Reload Nginx
docker-compose exec api-gateway nginx -s reload
```

### 8. Test End-to-End Connection

```bash
curl http://localhost/products/api/products
```

---

## 💡 Understanding the Magic

### Why Container Names Work as Hostnames?

Docker's embedded DNS server (at 127.0.0.11) resolves container names on the same network.

### Why Nginx Can Find Backend Services?

Because all containers are on `microservices-network`, Nginx can use container names as hostnames.

### Why Only Port 80 is Exposed?

Security! Backend services are isolated. Only the gateway needs external access.

### How Does Data Flow?

```
Client → Host Port 80 → Container Port 80 (Gateway) 
      → Docker Network → Backend Container 
      → Response back through same path
```

---

## 📚 Related Files

- `README.md` - Main setup guide
- `ARCHITECTURE.md` - Deep architecture details
- `docker-compose.yml` - Service orchestration
- `nginx.conf` - Routing configuration

---

**Now you understand exactly how everything connects!** 🎉
