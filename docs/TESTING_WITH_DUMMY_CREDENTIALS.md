# Testing with Dummy Credentials

This guide explains how to run the Gumroad test suite using dummy credentials instead of real API keys, ensuring security while maintaining test coverage.

## Overview

The test suite has been enhanced to work with dummy credentials, using a combination of:
- VCR cassettes for recorded API interactions
- Test skipping for tests that require real credentials
- Mock responses for certain services
- LocalStack for AWS services

## Setup

### 1. Environment Variables

Ensure your `.env.test` file contains dummy values (already configured):
```bash
TESTING_WITHOUT_SECRETS=true
STRIPE_API_KEY=dummy_stripe_secret_key_test
PAYPAL_USERNAME=dummy_paypal_username
# ... other dummy values
```

### 2. Docker Services

Start the required services using the existing Docker setup:
```bash
# MySQL, MongoDB, Redis, Elasticsearch, LocalStack
docker-compose up -d

# Or use the specific test ports:
DATABASE_PORT=32773
MONGO_DATABASE_URL=localhost:32769
REDIS_HOST=localhost:32770/10
SIDEKIQ_REDIS_HOST=localhost:32770/11
ELASTICSEARCH_HOST=http://localhost:32768
LOCALSTACK_ENDPOINT=http://localhost:32771
```

### 3. Running Tests

Run the full test suite with dummy credentials:
```bash
./test_locally.sh
```

Or run specific test directories:
```bash
./test_locally.sh spec/sidekiq
./test_locally.sh spec/models
./test_locally.sh spec/business
```

## How It Works

### DummyCredentialHelper Module

The `spec/support/dummy_credential_helper.rb` module provides utilities for handling dummy credentials:

- **`skip_if_using_dummy_credentials(*services)`** - Skips tests when using dummy credentials
- **`skip_without_vcr_cassette(*services)`** - Skips if no VCR cassette exists
- **`skip_without_localstack`** - Skips AWS tests if LocalStack isn't available
- **`ensure_test_infrastructure!`** - Sets up Elasticsearch indices and MongoDB connections
- **`mock_external_service(service)`** - Provides mock responses for external services

### VCR Configuration

VCR is configured in `spec/spec_helper.rb` to:
- Use existing cassettes without recording new ones
- Match requests more leniently with dummy credentials
- Allow playback repeats for multiple test runs
- Filter out authorization headers for flexibility

### Test Categories and Fixes

#### 1. MongoDB-Dependent Tests
Tests that use `BlockedObject` and other MongoDB models:
- Automatically skip if MongoDB is not available
- Examples: `block_email_domains_worker_spec.rb`, `blocked_object_spec.rb`

#### 2. Elasticsearch-Dependent Tests
Tests that require search functionality:
- Automatically create indices in test setup
- Examples: `product/sorting_spec.rb`, search-related specs

#### 3. Payment Processor Tests
Tests for Stripe, PayPal, Braintree:
- Use VCR cassettes when available
- Skip tests when cassettes don't exist
- Examples: `stripe_charge_processor_spec.rb`, `paypal_charge_processor_spec.rb`

#### 4. AWS/Video Processing Tests
Tests that require S3 or video transcoding:
- Skip unless LocalStack is configured
- Examples: `transcode_video_for_streaming_worker_spec.rb`, `asset_preview_spec.rb`

#### 5. External API Tests
Tests for TaxJar, SendGrid, OpenAI, etc.:
- Skip when using dummy credentials
- Use VCR cassettes where possible
- Examples: `send_year_in_review_email_job_spec.rb`, tax calculation specs

## Validation

### Validate VCR Cassettes

Check cassettes for exposed credentials:
```bash
ruby script/validate_vcr_cassettes.rb
```

This script will:
- Check for potential real credentials in cassettes
- Identify cassettes with dummy credential markers
- Report any security concerns

## Test Results

With dummy credentials, tests will show three types of results:

1. **✅ Passed** - Test executed successfully with dummy credentials/VCR
2. **⚠️ Skipped** - Test skipped due to dummy credentials (message explains why)
3. **❌ Failed** - Test failed (investigate and fix)

### Expected Skipped Tests

The following tests are expected to be skipped with dummy credentials:
- Real-time payment processing tests
- Live webhook handlers
- Email sending tests (without mocks)
- Video transcoding (without LocalStack)
- External API calls without VCR cassettes

## Troubleshooting

### MongoDB Connection Issues
```
MongoDB required for BlockedObject tests: Connection refused
```
**Solution:** Ensure MongoDB is running on port 32769

### Elasticsearch Index Missing
```
[404] {"error":{"type":"index_not_found_exception"}}
```
**Solution:** Indices are created automatically, but you can manually create:
```ruby
Purchase.__elasticsearch__.create_index! force: true
```

### VCR Cassette Not Found
```
VCR::Errors::UnhandledHTTPRequestError
```
**Solution:** Test will skip automatically with dummy credentials

### LocalStack Not Available
```
AWS tests require LocalStack or real credentials
```
**Solution:** Start LocalStack or the test will be skipped

## Adding New External Service Tests

When adding tests that use external services:

1. **Add service to DummyCredentialHelper**:
```ruby
when 'NEWSERVICE'
  ['NEWSERVICE_API_KEY']
```

2. **In your spec file**:
```ruby
describe NewServiceIntegration do
  include DummyCredentialHelper
  
  before do
    skip_without_vcr_cassette(:newservice)
  end
end
```

3. **Record VCR cassette** (with real credentials, once):
```ruby
VCR.use_cassette('new_service_test') do
  # test code
end
```

4. **Commit the cassette** (after validating no secrets):
```bash
ruby script/validate_vcr_cassettes.rb
```

## Security Best Practices

1. **Never commit real credentials** to the repository
2. **Always validate cassettes** before committing
3. **Use the validation script** regularly
4. **Prefer VCR cassettes** over test skipping
5. **Document skipped tests** in test output
6. **Keep dummy credentials consistent** (use `dummy_` prefix)

## CI/CD Considerations

For CI environments:
- Set `TESTING_WITHOUT_SECRETS=true`
- Ensure all required services are available
- VCR cassettes must be present (recording disabled)
- Tests that can't run will skip cleanly
- Monitor skipped test count for changes

## Maintenance

Periodically review:
- Skipped test count (shouldn't increase unexpectedly)
- VCR cassette validity
- New external services that need handling
- Test coverage metrics accounting for skips