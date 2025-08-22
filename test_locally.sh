#!/bin/bash

# Developer Test Script for Dummy Secrets Implementation
# Tests core functionality to ensure tests work without external API secrets
# Run this regularly during development - full test suite runs in CI

set -e

# Environment setup
eval "$(mise env)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing Dummy Secrets Implementation${NC}"
echo "========================================"

# Check if Docker services are running, start if needed
if ! docker compose -f docker/docker-compose-test-and-ci.yml ps | grep -q "Up"; then
    echo -e "${BLUE}🐳 Starting Docker services...${NC}"
    docker compose -f docker/docker-compose-test-and-ci.yml up -d
    sleep 5
fi

# Get dynamic ports
DB_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port db_test 3306 | cut -d: -f2)
REDIS_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port redis 6379 | cut -d: -f2)
MONGO_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port mongo 27017 | cut -d: -f2)
ELASTICSEARCH_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port elasticsearch 9200 | cut -d: -f2)
MEMCACHE_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port memcached 11211 | cut -d: -f2)
LOCALSTACK_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port localstack 4566 | cut -d: -f2)

echo -e "${BLUE}📋 Using services:${NC} MySQL:$DB_PORT | Redis:$REDIS_PORT | MongoDB:$MONGO_PORT | ES:$ELASTICSEARCH_PORT | LocalStack:$LOCALSTACK_PORT"

# Wait for critical services
./docker/ci/wait_on_connection.sh 127.0.0.1 "$DB_PORT" 30 "MySQL"
./docker/ci/wait_on_connection.sh 127.0.0.1 "$REDIS_PORT" 15 "Redis"

# Fast LocalStack setup (no health check delays)
echo -e "${BLUE}🪣 Setting up LocalStack S3...${NC}"
export LOCALSTACK_ENDPOINT="http://localhost:$LOCALSTACK_PORT"
docker exec docker-localstack-1 awslocal s3 mb s3://gumroad 2>/dev/null || true
docker exec docker-localstack-1 awslocal s3 mb s3://gumroad-specs 2>/dev/null || true

# Set environment variables
export DATABASE_NAME=gumroad_test
export DATABASE_HOST=127.0.0.1
export DATABASE_PORT="$DB_PORT"
export DATABASE_USERNAME=root
export DATABASE_PASSWORD=password
export REDIS_HOST="localhost:$REDIS_PORT/10"
export SIDEKIQ_REDIS_HOST="localhost:$REDIS_PORT/11"
export RPUSH_REDIS_HOST="localhost:$REDIS_PORT/12"
export RACK_ATTACK_REDIS_HOST="localhost:$REDIS_PORT/13"
export MONGO_DATABASE_URL="localhost:$MONGO_PORT"
export ELASTICSEARCH_HOST="http://localhost:$ELASTICSEARCH_PORT"
export MEMCACHE_SERVERS="localhost:$MEMCACHE_PORT"
export LOCALSTACK_ENDPOINT="http://localhost:$LOCALSTACK_PORT"
export RAILS_MASTER_KEY=dummy_rails_master_key_for_testing_32b
export STRIPE_API_KEY=dummy_stripe_secret_key_test
export PAYPAL_USERNAME=dummy_paypal_username
export AWS_ACCESS_KEY_ID=dummy_aws_access_key
export AWS_SECRET_ACCESS_KEY=dummy_aws_secret_key
export BRAINTREE_API_PRIVATE_KEY=dummy_braintree_private_key
export BRAINTREE_MERCHANT_ID=dummy_braintree_merchant
export BRAINTREE_PUBLIC_KEY=dummy_braintree_public_key
export BRAINTREE_MERCHANT_ACCOUNT_ID_FOR_SUPPLIERS=dummy_braintree_supplier_account
export RAILS_ENV=test

echo ""
echo -e "${BLUE}🧪 Running Core Test Suite (proves dummy secrets work)...${NC}"

# Run the helper specs - these cover the main areas that were fixed
# This is the sweet spot: comprehensive enough to catch issues, fast enough for daily use
if bundle exec rspec spec/helpers/ --format progress; then
    echo ""
    echo -e "${GREEN}✅ SUCCESS: All tests pass with dummy secrets!${NC}"
    echo -e "${GREEN}✅ PayoutsHelper: Merchant account validation fixed${NC}"
    echo -e "${GREEN}✅ ProductsHelper: S3 + CDN integration working${NC}" 
    echo -e "${GREEN}✅ SignedUrlHelper: S3 error handling working${NC}"
    echo ""
    echo -e "${BLUE}🎯 Your code works without external API dependencies${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ FAILURE: Some tests failed${NC}"
    echo -e "${YELLOW}💡 This means the dummy secrets implementation has issues${NC}"
    echo -e "${YELLOW}💡 Check the failing tests and fix the dummy credential logic${NC}"
    exit 1
fi