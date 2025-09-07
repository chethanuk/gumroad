#!/bin/bash
# Run business tests and capture full results

echo "Starting business test run at $(date)"

# Get ports from Docker
DB_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port db_test 3306 2>/dev/null | cut -d: -f2)
REDIS_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port redis 6379 2>/dev/null | cut -d: -f2)
MONGO_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port mongo 27017 2>/dev/null | cut -d: -f2)
ES_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port elasticsearch 9200 2>/dev/null | cut -d: -f2)
LOCALSTACK_PORT=$(docker compose -f docker/docker-compose-test-and-ci.yml port localstack 4566 2>/dev/null | cut -d: -f2)

echo "Ports: DB=$DB_PORT REDIS=$REDIS_PORT MONGO=$MONGO_PORT ES=$ES_PORT LOCALSTACK=$LOCALSTACK_PORT"

# Set all environment variables
export RAILS_ENV=test
export DATABASE_HOST=127.0.0.1
export DATABASE_PORT="$DB_PORT"
export DATABASE_NAME=gumroad_test
export DATABASE_USERNAME=root
export DATABASE_PASSWORD=password

export REDIS_HOST="localhost:$REDIS_PORT/10"
export SIDEKIQ_REDIS_HOST="localhost:$REDIS_PORT/11"

export MONGO_DATABASE_URL="localhost:$MONGO_PORT"
export MONGO_DATABASE_NAME=gumroad_log_test

export ELASTICSEARCH_HOST="http://localhost:$ES_PORT"
export LOCALSTACK_ENDPOINT="http://localhost:$LOCALSTACK_PORT"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=us-east-1
export S3_BUCKET=gumroad
export S3_SPECS_BUCKET=gumroad-specs

export TESTING_WITHOUT_SECRETS=true

# Dummy credentials
export STRIPE_API_KEY=dummy_stripe_key
export PAYPAL_CLIENT_ID=dummy_paypal_id
export BRAINTREE_MERCHANT_ID=dummy_braintree

echo "Running business tests..."
bundle exec rspec spec/business/ --format progress 2>&1
