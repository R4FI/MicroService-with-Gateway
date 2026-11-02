# API Gateway Architecture

## System Overview

This document explains the architecture of the API Gateway implementation using Docker, Nginx, and three microservices.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         CLIENT                               │
│                   (Browser, Mobile App, etc.)                │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ HTTP Requests
                            │ localhost:80
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    API GATEWAY (Nginx)                       │
│                    Container: api-gateway                    │
│                         Port: 80                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Routing Logic (nginx.conf)                        │    │
│  │  • /users/*     → usermanagementservice:5126       │    │
│  │  • /products/*  → productservice:5171              │    │
│  │  • /orders/*    → orderservice:5003                │    │
│  │  • /health      → Gateway health check             │    │
│  └────────────────────────────────────────────────────┘    │
└──────────┬─────────────────┬─────────────────┬─────────────┘
           │                 │                 │
           │ Docker Network: microservices-network
           │                 │                 │
           ▼                 ▼                 ▼
┌──────────────────┐ ┌──────────────┐ ┌─────────────────┐
│ User Management  │ │   Product    │ │  Order Service  │
│    Service       │ │   Service    │ │                 │
├──────────────────┤ ├──────────────┤ ├─────────────────┤
│ ASP.NET Core     │ │ ASP.NET Core │ │  Spring Boot    │
│ Container:       │ │ Container:   │ │  Container:     │
│ usermanagement   │ │ productservice│ │  orderservice   │
│ Port: 5126       │ │ Port: 5171   │ │  Port: 5003     │
│ (Internal only)  │ │ (Internal)   │ │  (Internal)     │
└──────────┬───────┘ └──────┬───────┘ └────────┬────────┘
           │                │                   │
           ▼                ▼                   ▼
   ┌──────────────┐ ┌──────────────┐  ┌──────────────┐
   │   MongoDB    │ │   MongoDB    │  │   MongoDB    │
   │   (Cloud)    │ │   (Cloud)    │  │   (Cloud)    │
   └──────────────┘ └──────────────┘  └──────────────┘
```

## Component Breakdown

### 1. API Gateway (Nginx)

**Purpose**: Single entry point for all client requests

**Technology**: Nginx (lightweight web server and reverse proxy)

**Responsibilities**:
- Receive all incoming HTTP requests on port 80
- Route requests to appropriate backend services based on URL path
- Add proxy headers (X-Real-IP, X-Forwarded-For, etc.)
- Handle CORS, if configured
- Provide gateway health check endpoint
- Log all requests centrally

**Why Nginx?**
- High performance and low resource usage
- Battle-tested reverse proxy capabilities
- Simple configuration
- Built-in load balancing support
- Excellent for container environments

### 2. User Management Service

**Purpose**: Handle user-related operations (CRUD for users)

**Technology**: ASP.NET Core 9.0

**Port**: 5126 (internal to Docker network only)

**Key Features**:
- User registration and authentication
- User profile management
- MongoDB integration for data persistence

**Why Internal Port?**
- Not exposed to host machine (security)
- Only accessible through API Gateway
- Prevents direct external access

### 3. Product Service

**Purpose**: Handle product catalog operations

**Technology**: ASP.NET Core 9.0

**Port**: 5171 (internal to Docker network only)

**Key Features**:
- Product CRUD operations
- Product search and filtering
- MongoDB integration for data storage

**Why Internal Port?**
- Isolated from external access
- Gateway controls all access
- Easier to scale and secure

### 4. Order Service

**Purpose**: Handle order processing and management

**Technology**: Spring Boot (Java)

**Port**: 5003 (internal to Docker network only)

**Key Features**:
- Order creation and tracking
- Order history
- MongoDB integration

**Why Spring Boot?**
- Different from .NET services (demonstrates polyglot architecture)
- Built-in production-ready features (Actuator)
- Strong ecosystem

## Network Architecture

### Docker Network: microservices-network

**Type**: Bridge network

**Purpose**: Enable inter-container communication

**How It Works**:
1. Docker creates an internal network isolated from the host
2. Each service gets a unique IP on this network
3. Docker's DNS resolves container names to IPs
4. Services communicate using container names as hostnames

**Example**:
```
Nginx config: upstream user_service { server usermanagementservice:5126; }
Docker DNS resolves: usermanagementservice → 172.18.0.3
```

**Benefits**:
- Services are isolated from external network
- No port conflicts between services
- Easy service discovery by name
- Secure internal communication

## Request Flow

### Example: Get All Users

```
1. Client Request
   └─→ GET http://localhost/users/api/users

2. API Gateway (Nginx) Receives Request
   ├─→ Matches location /users/ block in nginx.conf
   ├─→ Adds proxy headers (X-Real-IP, X-Forwarded-For)
   └─→ Routes to upstream: user_service

3. Docker Network Resolution
   └─→ Resolves 'usermanagementservice' to container IP

4. User Management Service
   ├─→ Receives: GET /api/users (note: /users/ prefix removed)
   ├─→ Processes request
   ├─→ Queries MongoDB
   └─→ Returns JSON response

5. Response Path
   └─→ Service → Gateway → Client
```

## Port Mapping Strategy

### External (Host) Ports
- **Port 80**: API Gateway (only exposed port)

### Internal (Docker Network) Ports
- **Port 5126**: User Management Service
- **Port 5171**: Product Service
- **Port 5003**: Order Service

**Why This Strategy?**
- **Security**: Backend services not directly accessible from outside
- **Flexibility**: Can change internal ports without affecting clients
- **Simplicity**: Clients only need to know one endpoint (localhost:80)

## URL Routing Pattern

The gateway uses path-based routing:

| Client Request | Gateway Routes To | Backend Receives |
|----------------|-------------------|------------------|
| `GET /users/api/users` | `usermanagementservice:5126` | `GET /api/users` |
| `GET /products/api/products` | `productservice:5171` | `GET /api/products` |
| `GET /orders/api/orders` | `orderservice:5003` | `GET /api/orders` |

**Note**: The `/users/`, `/products/`, and `/orders/` prefixes are stripped by Nginx (due to `proxy_pass http://service/`)

## Security Considerations

### Current Implementation (Development)
- All services on internal Docker network
- Only gateway exposed to host
- No authentication/authorization at gateway level
- HTTP only (no HTTPS)

### Production Recommendations
1. **HTTPS/SSL**
   - Add SSL certificates to Nginx
   - Force HTTPS redirects
   - Use Let's Encrypt for free certificates

2. **Authentication**
   - Implement JWT token validation at gateway
   - Add API key authentication
   - Use OAuth 2.0 for third-party access

3. **Rate Limiting**
   ```nginx
   limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
   limit_req zone=api burst=20;
   ```

4. **CORS Configuration**
   ```nginx
   add_header 'Access-Control-Allow-Origin' '*';
   add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
   ```

5. **Request Size Limits**
   ```nginx
   client_max_body_size 10M;
   ```

## Scalability

### Current Setup
- Single instance of each service
- No load balancing

### Scaling Horizontally

To add multiple instances of a service:

```yaml
# docker-compose.yml
usermanagementservice:
  build: ./UserManagementService
  deploy:
    replicas: 3  # Run 3 instances
```

Nginx will automatically load balance across instances:

```nginx
upstream user_service {
    server usermanagementservice1:5126;
    server usermanagementservice2:5126;
    server usermanagementservice3:5126;
    # Nginx uses round-robin by default
}
```

## Monitoring and Logging

### Current Logging
- Nginx logs all requests to stdout
- Each service logs to its own stdout
- Docker Compose aggregates all logs

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api-gateway
```

### Production Monitoring Recommendations
1. **Centralized Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)
2. **Metrics**: Prometheus + Grafana
3. **Tracing**: Jaeger or Zipkin for distributed tracing
4. **Health Checks**: Automated health monitoring with alerts

## Benefits of This Architecture

### 1. Loose Coupling
- Services are independent
- Can be deployed separately
- Different technologies can coexist

### 2. Single Entry Point
- Clients don't need to know about multiple URLs
- Easier to manage CORS and security policies
- Centralized request logging

### 3. Service Discovery
- Docker DNS handles service location
- No hardcoded IPs
- Services can be moved/scaled without client changes

### 4. Security
- Backend services not directly exposed
- Gateway can implement authentication/authorization
- Rate limiting and DDoS protection at single point

### 5. Flexibility
- Easy to add new services
- Simple to version APIs (/v1/users/, /v2/users/)
- Can implement A/B testing or canary deployments

## Deployment Workflow

```bash
# 1. Build all images
docker-compose build

# 2. Start all services
docker-compose up -d

# 3. Verify all services are running
docker-compose ps

# 4. Check health
curl http://localhost/health

# 5. Test endpoints
curl http://localhost/users/
curl http://localhost/products/
curl http://localhost/orders/

# 6. View logs
docker-compose logs -f

# 7. Stop all services
docker-compose down
```

## Common Issues and Solutions

### Issue: Port 80 already in use
**Solution**: Change the exposed port in docker-compose.yml
```yaml
ports:
  - "8080:80"  # Use 8080 instead
```

### Issue: Service not reachable
**Solution**: 
1. Check if all containers are running: `docker-compose ps`
2. Check logs: `docker-compose logs [service-name]`
3. Verify Docker network: `docker network inspect microservice-with-gateway_microservices-network`

### Issue: Changes not reflected
**Solution**: Rebuild the images
```bash
docker-compose up --build
```

## Summary

This API Gateway architecture provides:
- ✅ Single entry point for all services
- ✅ Service isolation and security
- ✅ Easy routing and load balancing
- ✅ Polyglot architecture support (different languages)
- ✅ Simple deployment with Docker Compose
- ✅ Scalability and maintainability
- ✅ Centralized logging and monitoring
