#!/bin/bash
# Startup script for API Gateway and Microservices
# This script builds and starts all services with proper error handling

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    echo -e "${2}${1}${NC}"
}

# Print header
print_header() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
    echo ""
}

# Check if Docker is running
check_docker() {
    print_message "Checking Docker status..." "$BLUE"
    if ! docker info > /dev/null 2>&1; then
        print_message "❌ Docker is not running. Please start Docker and try again." "$RED"
        exit 1
    fi
    print_message "✅ Docker is running" "$GREEN"
}

# Check if Docker Compose is installed
check_docker_compose() {
    print_message "Checking Docker Compose..." "$BLUE"
    if ! command -v docker-compose &> /dev/null; then
        print_message "❌ Docker Compose is not installed." "$RED"
        exit 1
    fi
    print_message "✅ Docker Compose is available" "$GREEN"
}

# Stop existing containers
stop_existing() {
    print_message "Stopping existing containers..." "$YELLOW"
    docker-compose down
}

# Build and start services
start_services() {
    print_header "Building and Starting Services"
    print_message "This may take several minutes on first run..." "$YELLOW"
    
    # Build and start in detached mode
    if docker-compose up --build -d; then
        print_message "✅ All services started successfully!" "$GREEN"
    else
        print_message "❌ Failed to start services. Check logs above for errors." "$RED"
        exit 1
    fi
}

# Wait for services to be healthy
wait_for_services() {
    print_header "Waiting for Services to be Ready"
    
    # Wait for gateway
    print_message "Waiting for API Gateway..." "$BLUE"
    timeout=60
    counter=0
    until curl -s http://localhost/health > /dev/null 2>&1; do
        sleep 2
        counter=$((counter + 2))
        if [ $counter -ge $timeout ]; then
            print_message "⚠️  Timeout waiting for API Gateway" "$YELLOW"
            break
        fi
        echo -n "."
    done
    
    if [ $counter -lt $timeout ]; then
        echo ""
        print_message "✅ API Gateway is ready!" "$GREEN"
    fi
}

# Display service status
show_status() {
    print_header "Service Status"
    docker-compose ps
}

# Display access information
show_access_info() {
    print_header "Access Information"
    echo ""
    print_message "🌐 API Gateway:           http://localhost" "$GREEN"
    print_message "📋 Gateway Info:          http://localhost/" "$BLUE"
    print_message "❤️  Health Check:          http://localhost/health" "$BLUE"
    echo ""
    print_message "📦 Service Endpoints:" "$YELLOW"
    print_message "   • Users:    http://localhost/users/" "$BLUE"
    print_message "   • Products: http://localhost/products/" "$BLUE"
    print_message "   • Orders:   http://localhost/orders/" "$BLUE"
    echo ""
    print_message "📊 View logs: docker-compose logs -f" "$YELLOW"
    print_message "🛑 Stop all:  docker-compose down" "$YELLOW"
    echo ""
}

# Main execution
main() {
    clear
    print_header "🚀 API Gateway Startup Script"
    
    # Pre-flight checks
    check_docker
    check_docker_compose
    
    # Stop existing containers
    stop_existing
    
    # Start services
    start_services
    
    # Wait for services
    wait_for_services
    
    # Show status
    show_status
    
    # Show access info
    show_access_info
    
    print_message "✨ Setup complete! Your API Gateway is running." "$GREEN"
}

# Run main function
main
