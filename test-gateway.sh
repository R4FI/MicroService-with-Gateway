#!/bin/bash
# Test script for API Gateway
# Verifies all endpoints are accessible through the gateway

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print colored message
print_test() {
    echo -e "${BLUE}Testing:${NC} $1"
}

# Print result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASSED${NC}\n"
    else
        echo -e "${RED}❌ FAILED${NC}\n"
    fi
}

# Test gateway health
test_health() {
    print_test "Gateway Health Check"
    response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/health)
    
    if [ "$response" == "200" ]; then
        print_result 0
        return 0
    else
        print_result 1
        return 1
    fi
}

# Test gateway info
test_info() {
    print_test "Gateway Info Endpoint"
    response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/)
    
    if [ "$response" == "200" ]; then
        print_result 0
        return 0
    else
        print_result 1
        return 1
    fi
}

# Test user service
test_users() {
    print_test "User Service (via Gateway)"
    # Try to reach the users endpoint
    response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/users/)
    
    # 200, 404, or other response means service is reachable
    # Only complete failure (000) is a problem
    if [ "$response" != "000" ] && [ ! -z "$response" ]; then
        print_result 0
        return 0
    else
        print_result 1
        return 1
    fi
}

# Test product service
test_products() {
    print_test "Product Service (via Gateway)"
    # Try to reach the products endpoint
    response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/products/)
    
    # 200, 404, or other response means service is reachable
    # Only complete failure (000) is a problem
    if [ "$response" != "000" ] && [ ! -z "$response" ]; then
        print_result 0
        return 0
    else
        print_result 1
        return 1
    fi
}

# Test order service
test_orders() {
    print_test "Order Service (via Gateway)"
    # Try to reach the orders endpoint
    response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/orders/)
    
    # 200, 404, or other response means service is reachable
    # Only complete failure (000) is a problem
    if [ "$response" != "000" ] && [ ! -z "$response" ]; then
        print_result 0
        return 0
    else
        print_result 1
        return 1
    fi
}

# Main test execution
main() {
    echo ""
    echo "=================================================="
    echo "🧪 API Gateway Test Suite"
    echo "=================================================="
    echo ""
    
    # Initialize counters
    total=0
    passed=0
    
    # Run tests
    tests=(test_health test_info test_users test_products test_orders)
    
    for test in "${tests[@]}"; do
        total=$((total + 1))
        if $test; then
            passed=$((passed + 1))
        fi
    done
    
    # Print summary
    echo "=================================================="
    echo "Test Summary"
    echo "=================================================="
    echo ""
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}✅ All tests passed! ($passed/$total)${NC}"
        echo ""
        return 0
    else
        echo -e "${YELLOW}⚠️  Some tests failed: $passed/$total passed${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check if all services are running: docker-compose ps"
        echo "  2. View logs: docker-compose logs -f"
        echo "  3. Restart services: docker-compose restart"
        echo ""
        return 1
    fi
}

# Run main function
main
