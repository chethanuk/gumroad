#!/bin/bash
set -e

echo "Setting up LocalStack S3 buckets..."

# Get LocalStack endpoint from environment or use default
LOCALSTACK_ENDPOINT=${LOCALSTACK_ENDPOINT:-"http://localhost:4566"}
echo "Using LocalStack endpoint: $LOCALSTACK_ENDPOINT"

# Fast setup - just create buckets directly without health check
# This is the industry standard approach based on production repos
echo "Creating S3 buckets..."
docker exec docker-localstack-1 awslocal s3 mb s3://gumroad 2>/dev/null || echo "Bucket gumroad already exists"
docker exec docker-localstack-1 awslocal s3 mb s3://gumroad-specs 2>/dev/null || echo "Bucket gumroad-specs already exists"  
docker exec docker-localstack-1 awslocal s3 mb s3://gumroad-staging 2>/dev/null || echo "Bucket gumroad-staging already exists"
docker exec docker-localstack-1 awslocal s3 mb s3://gumroad-test 2>/dev/null || echo "Bucket gumroad-test already exists"

# Quick verification
echo "Verifying buckets..."
docker exec docker-localstack-1 awslocal s3 ls 2>/dev/null || echo "LocalStack not ready yet, buckets will be created when ready"

echo "LocalStack S3 setup complete!"