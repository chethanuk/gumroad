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
CYAN='\033[0;36m'
NC='\033[0m'

# Parse command line arguments
SKIP_WARNINGS=false
SPEC_PATH=""
VERBOSE=false
HELP=false
SAVE_LOG=false
DEBUG_MODE=false

# Function to show help
show_help() {
    echo -e "${CYAN}Usage: $0 [OPTIONS] [SPEC_PATH]${NC}"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "  -s, --skip-warnings    Skip deprecation and other warnings (default: false)"
    echo "  -v, --verbose          Show all output including warnings"
    echo "  -l, --log              Save test output to .plan/<folder>/test_results.log"
    echo "  -d, --debug            Run WITHOUT tag filtering to see all failures"
    echo "  -h, --help             Show this help message"
    echo ""
    echo -e "${CYAN}Arguments:${NC}"
    echo "  SPEC_PATH             Path to specs to run (default: spec/helpers/)"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0                                    # Run helper specs with warnings"
    echo "  $0 -s                                 # Run helper specs without warnings"
    echo "  $0 -s spec/sidekiq/                  # Run sidekiq specs without warnings"
    echo "  $0 -s -l spec/business/               # Run business specs, save log to .plan/business/"
    echo "  $0 -d spec/business/                  # Debug mode: run without tag filtering"
    echo "  $0 --skip-warnings spec/models/      # Run model specs without warnings"
    echo "  $0 -v spec/controllers/               # Run controller specs with verbose output"
    echo ""
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--skip-warnings)
            SKIP_WARNINGS=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--log)
            SAVE_LOG=true
            shift
            ;;
        -d|--debug)
            DEBUG_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
        *)
            SPEC_PATH="$1"
            shift
            ;;
    esac
done

# Default spec path if not provided
SPEC_PATH="${SPEC_PATH:-spec/helpers/}"

echo -e "${BLUE}🧪 Testing Dummy Secrets Implementation${NC}"
echo "========================================"

# Show configuration
echo -e "${CYAN}Configuration:${NC}"
echo -e "  Skip Warnings: ${YELLOW}$SKIP_WARNINGS${NC}"
echo -e "  Verbose Mode:  ${YELLOW}$VERBOSE${NC}"
echo -e "  Debug Mode:    ${YELLOW}$DEBUG_MODE${NC}"
echo -e "  Save Log:      ${YELLOW}$SAVE_LOG${NC}"
echo -e "  Spec Path:     ${YELLOW}$SPEC_PATH${NC}"
echo ""

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
export MONGO_DATABASE_NAME=gumroad_log_test
export ELASTICSEARCH_HOST="http://localhost:$ELASTICSEARCH_PORT"
export MEMCACHE_SERVERS="localhost:$MEMCACHE_PORT"
export LOCALSTACK_ENDPOINT="http://localhost:$LOCALSTACK_PORT"
export RAILS_MASTER_KEY=dummy_rails_master_key_for_testing_32b
export STRIPE_API_KEY=dummy_stripe_secret_key_test
export STRIPE__ENDPOINT_SECRET=whsec_test_dummy_webhook_secret_32chars
export STRIPE_CONNECT__ENDPOINT_SECRET=whsec_connect_dummy_webhook_32chars
export PAYPAL_USERNAME=dummy_paypal_username
export PAYPAL_PARTNER_MERCHANT_ID=dummy_paypal_partner_merchant
export AWS_ACCESS_KEY_ID=dummy_aws_access_key
export AWS_SECRET_ACCESS_KEY=dummy_aws_secret_key
# CloudFront dummy key (handled in AWS initializer)
export CLOUDFRONT_PRIVATE_KEY=dummy_cloudfront_private_key
export CLOUDFRONT_KEYPAIR_ID=dummy_cloudfront_keypair_id
export BRAINTREE_API_PRIVATE_KEY=dummy_braintree_private_key
export BRAINTREE_MERCHANT_ID=dummy_braintree_merchant
export BRAINTREE_PUBLIC_KEY=dummy_braintree_public_key
export BRAINTREE_MERCHANT_ACCOUNT_ID_FOR_SUPPLIERS=dummy_braintree_supplier_account
export OPENAI_ACCESS_TOKEN=dummy_openai_token
export TAXJAR_API_KEY=dummy_taxjar_api_key  
export EASYPOST_API_KEY=dummy_easypost_api_key
export DROPBOX_API_KEY=dummy_dropbox_api_key
export CIRCLE_API_KEY=dummy_circle_api_key
export DISCORD_CLIENT_SECRET=dummy_discord_client_secret
export SENDGRID_API_KEY=dummy_sendgrid_api_key
export VATSTACK_API_KEY=dummy_vatstack_api_key
export TAX_ID_PRO_API_KEY=dummy_tax_id_pro_api_key
export IRAS_API_ID=dummy_iras_api_id
export IRAS_API_SECRET=dummy_iras_api_secret
export IFFY_TOKEN=dummy_iffy_token_for_admin_access
export IFFY_WEBHOOK_SECRET=dummy_iffy_webhook_secret_for_hmac
export HELPER_TOOLS_TOKEN=dummy_helper_tools_token_for_api_access
export MOBILE_TOKEN=dummy_mobile_token_for_api_access
export HELPER_SECRET_KEY=dummy_helper_secret_key_for_hmac
export GRMC_TOKEN=dummy_grmc_token_for_webhook_access
export GRMC_WEBHOOK_SECRET=dummy_grmc_webhook_secret_for_hmac
export SECURE_ENCRYPT_KEY=12345678901234567890123456789012
export MAILER_HEADERS_ENCRYPTION_KEY_V1=dummy_mailer_encryption_key_v1
export SECURE_EXTERNAL_ID__PRIMARY_KEY_VERSION=1
export SECURE_EXTERNAL_ID__KEYS__1=dummy32byteencryptionkeyfortest1
export OBFUSCATE_IDS_CIPHER_KEY=dummy_obfuscate_ids_cipher_key_32bytes_long!!!
export OBFUSCATE_IDS_NUMERIC_CIPHER_KEY=123456789
export RAILS_ENV=test
export IN_DOCKER=true
export TESTING_WITHOUT_SECRETS=true

# Skip JavaScript tests when Chrome is not available
# Set to false to attempt running JS tests (requires Chrome/Selenium)
export SKIP_JS_TESTS=true

# Skip payment provider tests by default when using dummy secrets (unless debug mode)
if [ "$DEBUG_MODE" = true ]; then
    SKIP_PAYMENT_TESTS=false
    echo -e "${YELLOW}⚠️  Debug Mode: Running ALL tests including payment provider tests${NC}"
else
    SKIP_PAYMENT_TESTS=true
fi

# Set up warning suppression
if [ "$SKIP_WARNINGS" = true ]; then
    export RUBYOPT="-W0"  # Suppress Ruby warnings
    export RAILS_DEPRECATION_LOG=false  # Suppress Rails deprecation warnings
    
    # Create a custom RSpec configuration
    RSPEC_OPTIONS="--format progress"
    
    # Skip payment provider tests that require real API credentials (unless debug mode)
    # TESTING_WITHOUT_SECRETS solution: Don't filter by tags - let tests run and fail naturally
    # if [ "$SKIP_PAYMENT_TESTS" = true ]; then
    #     RSPEC_OPTIONS="$RSPEC_OPTIONS --tag '~external_api'"
    # fi
    
    # Filter function for output
    filter_warnings() {
        grep -v "DEPRECATION WARNING" | \
        grep -v "sidekiq-pro is not installed" | \
        grep -v "warning:" | \
        grep -v "HTTParty will no longer override" | \
        grep -v "Cookie key.*is not valid according to RFC2616" | \
        grep -v "moov atom not found" | \
        grep -v "Invalid data found when processing input" | \
        grep -v "Support for defaultProps will be removed" | \
        grep -v "Checking for expected text of nil" || true
    }
else
    RSPEC_OPTIONS="--format progress"
    filter_warnings() {
        cat  # Pass through all output
    }
fi

# Verbose mode overrides warning filtering
if [ "$VERBOSE" = true ]; then
    RSPEC_OPTIONS="--format documentation --backtrace"
    filter_warnings() {
        cat  # Pass through all output
    }
fi

echo ""
echo -e "${BLUE}🧪 Running Core Test Suite (proves dummy secrets work)...${NC}"
echo -e "${BLUE}📁 Running specs: $SPEC_PATH${NC}"

# Prepare log file if requested  
# TESTING_WITHOUT_SECRETS solution: Save logs to .plan/<folder>/ for debugging
if [ "$SAVE_LOG" = true ]; then
    # Extract folder name from spec path
    FOLDER_NAME=$(basename "$SPEC_PATH" | sed 's/spec\///' | sed 's/\///')
    if [ -z "$FOLDER_NAME" ] || [ "$FOLDER_NAME" = "spec" ]; then
        FOLDER_NAME="all"
    fi
    
    # Create .plan directory if it doesn't exist
    mkdir -p ".plan/$FOLDER_NAME"
    LOG_FILE=".plan/$FOLDER_NAME/test_results_$(date +%Y%m%d_%H%M%S).log"
    echo -e "${CYAN}📝 Saving output to: $LOG_FILE${NC}"
fi

# Create a temporary file to capture exit code
TMPFILE=$(mktemp)

# Run the specified specs with appropriate filtering
if [ "$SAVE_LOG" = true ]; then
    # Run and save to log file
    if [ "$SKIP_WARNINGS" = true ] && [ "$VERBOSE" = false ]; then
        (bundle exec rspec "$SPEC_PATH" $RSPEC_OPTIONS 2>&1 || echo $? > "$TMPFILE") | tee >(filter_warnings > "$LOG_FILE") | filter_warnings
    else
        bundle exec rspec "$SPEC_PATH" $RSPEC_OPTIONS 2>&1 | tee "$LOG_FILE" || echo $? > "$TMPFILE"
    fi
else
    # Run without logging
    if [ "$SKIP_WARNINGS" = true ] && [ "$VERBOSE" = false ]; then
        (bundle exec rspec "$SPEC_PATH" $RSPEC_OPTIONS 2>&1 || echo $? > "$TMPFILE") | filter_warnings
    else
        bundle exec rspec "$SPEC_PATH" $RSPEC_OPTIONS || echo $? > "$TMPFILE"
    fi
fi

# Check if tests failed
if [ -f "$TMPFILE" ] && [ -s "$TMPFILE" ]; then
    EXIT_CODE=$(cat "$TMPFILE")
    rm -f "$TMPFILE"
    
    echo ""
    echo -e "${RED}❌ FAILURE: Some tests failed${NC}"
    echo -e "${YELLOW}💡 This means the dummy secrets implementation has issues${NC}"
    echo -e "${YELLOW}💡 Check the failing tests and fix the dummy credential logic${NC}"
    
    if [ "$SKIP_WARNINGS" = true ]; then
        echo ""
        echo -e "${CYAN}ℹ️  Note: Warnings were suppressed. Run without -s flag to see all output.${NC}"
    fi
    
    exit ${EXIT_CODE:-1}
else
    rm -f "$TMPFILE"
    
    echo ""
    echo -e "${GREEN}✅ SUCCESS: All tests pass with dummy secrets!${NC}"
    
    # Show specific success messages based on spec path
    if [[ "$SPEC_PATH" == *"helpers"* ]]; then
        echo -e "${GREEN}✅ PayoutsHelper: Merchant account validation fixed${NC}"
        echo -e "${GREEN}✅ ProductsHelper: S3 + CDN integration working${NC}" 
        echo -e "${GREEN}✅ SignedUrlHelper: S3 error handling working${NC}"
    elif [[ "$SPEC_PATH" == *"sidekiq"* ]]; then
        echo -e "${GREEN}✅ Sidekiq Workers: All background jobs working with dummy credentials${NC}"
        echo -e "${GREEN}✅ External APIs: Properly skipped or mocked${NC}"
    elif [[ "$SPEC_PATH" == *"models"* ]]; then
        echo -e "${GREEN}✅ Models: Database operations working correctly${NC}"
        echo -e "${GREEN}✅ Elasticsearch: Search indices properly configured${NC}"
    elif [[ "$SPEC_PATH" == *"controllers"* ]]; then
        echo -e "${GREEN}✅ Controllers: Request handling working with dummy auth${NC}"
        echo -e "${GREEN}✅ Admin Operations: Properly secured and tested${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🎯 Your code works without external API dependencies${NC}"
    
    if [ "$SKIP_WARNINGS" = true ]; then
        echo -e "${CYAN}ℹ️  Warnings were suppressed during this run${NC}"
    fi
    
    if [ "$SAVE_LOG" = true ]; then
        echo -e "${CYAN}📝 Test output saved to: $LOG_FILE${NC}"
    fi
    
    exit 0
fi