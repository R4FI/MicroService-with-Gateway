# API Gateway with Docker and Nginx

## Overview

This project implements a simple API Gateway using **Nginx** and **Docker** to provide a single entry point for three microservices:

1. **User Management Service** (ASP.NET Core) - Port 5126
2. **Product Service** (ASP.NET Core) - Port 5171
3. **Order Service** (Spring Boot) - Port 5003

## Architecture

```
Client
   ↓
localhost:80 (API Gateway - Nginx)
   ↓
   ├─→ /users/*    → User Management Service (5126)
   ├─→ /products/* → Product Service (5171)
   └─→ /orders/*   → Order Service (5003)
```

## Why API Gateway?

### Benefits:
- **Single Entry Point**: Clients only need to know one URL (localhost:80)
- **Simplified Client Logic**: No need to track multiple service URLs
- **Security**: Backend services are not directly exposed to clients
- **Load Balancing**: Can distribute requests across multiple instances
- **Centralized Logging**: All requests logged in one place
- **Request Routing**: Intelligent routing based on URL patterns

## Project Structure

```
MicroService-with-Gateway/
├── nginx.conf              # Nginx routing configuration
├── Dockerfile.gateway      # Docker image for API Gateway
├── docker-compose.yml      # Orchestrates all services
├── ProductService/
│   ├── Dockerfile          # Product service container
│   └── ...
├── UserManagementService/
│   ├── Dockerfile          # User service container
│   └── ...
└── orderservice/
    ├── Dockerfile          # Order service container
    └── ...
```

## Quick Start

### Prerequisites
- Docker installed
- Docker Compose installed

### Step 1: Build and Start All Services

```bash
# Navigate to project root
cd /Users/rafi/MicroService-with-Gateway

# Build and start all services
docker-compose up --build
```

This command will:
1. Build Docker images for all three microservices
2. Build the API Gateway image
3. Start all containers
4. Create a network for inter-service communication

### Step 2: Verify Gateway is Running

```bash
# Check if all containers are running
docker-compose ps

# Test the gateway health
curl http://localhost/health
```

## API Endpoints

All requests go through `http://localhost` (port 80)

### Gateway Endpoints

- **GET** `http://localhost/` - Gateway information and available endpoints
- **GET** `http://localhost/health` - Gateway health check

### User Management Service

- **Base URL**: `http://localhost/users/`
- **Examples**:
  - `GET http://localhost/users/api/users` - Get all users
  - `POST http://localhost/users/api/users` - Create a user
  - `GET http://localhost/users/api/users/{id}` - Get user by ID

### Product Service

- **Base URL**: `http://localhost/products/`
- **Examples**:
  - `GET http://localhost/products/api/products` - Get all products
  - `POST http://localhost/products/api/products` - Create a product
  - `GET http://localhost/products/api/products/{id}` - Get product by ID

### Order Service

- **Base URL**: `http://localhost/orders/`
- **Examples**:
  - `GET http://localhost/orders/api/orders` - Get all orders
  - `POST http://localhost/orders/api/orders` - Create an order
  - `GET http://localhost/orders/api/orders/{id}` - Get order by ID

## Testing the API Gateway

### Test Gateway Health

```bash
curl http://localhost/health
# Expected: API Gateway is healthy
```

### Test Gateway Info

```bash
curl http://localhost/
# Expected: JSON with available endpoints
```

### Test User Service

```bash
# Get all users
curl http://localhost/users/api/users

# Create a user (example)
curl -X POST http://localhost/users/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

### Test Product Service

```bash
# Get all products
curl http://localhost/products/api/products

# Create a product (example)
curl -X POST http://localhost/products/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","price":999.99}'
```

### Test Order Service

```bash
# Get all orders
curl http://localhost/orders/api/orders

# Create an order (example)
curl -X POST http://localhost/orders/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":"123","productId":"456","quantity":1}'
```

## Docker Commands

### Start Services (Detached Mode)

```bash
docker-compose up -d
```

### Stop Services

```bash
docker-compose down
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api-gateway
docker-compose logs -f usermanagementservice
docker-compose logs -f productservice
docker-compose logs -f orderservice
```

### Rebuild Services

```bash
# Rebuild all services
docker-compose up --build

# Rebuild specific service
docker-compose up --build api-gateway
```

### View Running Containers

```bash
docker-compose ps
```

## How It Works

### Nginx Configuration

The `nginx.conf` file defines:

1. **Upstream Blocks**: Define backend services
   - Each service has a name that Docker DNS resolves
   - Example: `upstream user_service { server usermanagementservice:5126; }`

2. **Location Blocks**: Route requests based on URL path
   - `/users/` → forwards to User Management Service
   - `/products/` → forwards to Product Service
   - `/orders/` → forwards to Order Service

3. **Proxy Headers**: Preserve client information
   - `X-Real-IP`: Original client IP address
   - `X-Forwarded-For`: Request path through proxies
   - `X-Forwarded-Proto`: Original protocol (http/https)

### Docker Networking

- All services run on a custom bridge network: `microservices-network`
- Services communicate using container names (Docker DNS)
- Only the API Gateway exposes port 80 to the host
- Backend services are isolated and only accessible through the gateway

### Request Flow

1. Client sends request to `http://localhost/users/api/users`
2. API Gateway (Nginx) receives the request
3. Nginx matches the `/users/` path to the user_service upstream
4. Request is proxied to `http://usermanagementservice:5126/api/users`
5. User Management Service processes the request
6. Response flows back through Nginx to the client

## Troubleshooting

### Gateway Not Accessible

```bash
# Check if containers are running
docker-compose ps

# Check gateway logs
docker-compose logs api-gateway
```

### Service Not Responding

```bash
# Check specific service logs
docker-compose logs usermanagementservice
docker-compose logs productservice
docker-compose logs orderservice

# Check if service is healthy
docker-compose ps
```

### Port Already in Use

If port 80 is already in use, edit `docker-compose.yml`:

```yaml
api-gateway:
  ports:
    - "8080:80"  # Change to 8080 or any available port
```

Then access via `http://localhost:8080`

### Reset Everything

```bash
# Stop and remove all containers, networks, and volumes
docker-compose down -v

# Rebuild from scratch
docker-compose up --build
```

## Production Considerations

For production deployment, consider:

1. **HTTPS/SSL**: Add SSL certificates and configure HTTPS
2. **Rate Limiting**: Prevent abuse by limiting requests per client
3. **Authentication**: Add API key or OAuth authentication
4. **CORS**: Configure Cross-Origin Resource Sharing
5. **Load Balancing**: Add multiple instances of each service
6. **Health Checks**: Monitor service health automatically
7. **Logging**: Centralized logging with ELK stack or similar
8. **Monitoring**: Add Prometheus/Grafana for metrics

## Summary

This API Gateway provides:
- ✅ Single entry point at `http://localhost`
- ✅ Three microservices isolated in Docker containers
- ✅ Nginx for intelligent request routing
- ✅ Easy deployment with Docker Compose
- ✅ Health monitoring capabilities
- ✅ Comprehensive logging
