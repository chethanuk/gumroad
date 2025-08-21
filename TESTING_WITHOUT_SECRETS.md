# Testing Without Secrets

This document explains how to run Gumroad tests without requiring actual API credentials. This feature enables external contributors to run tests and allows CI/CD environments to function without exposing sensitive secrets.

## Overview

The testing infrastructure supports two modes:

1. **Dummy Secrets Mode**: Uses placeholder values for all external API credentials
2. **Real Secrets Mode**: Uses actual API credentials for full integration testing

## Quick Start

### For External Contributors

If you don't have access to Gumroad's API credentials, you can run tests using dummy secrets:

```bash
# Set the dummy mode environment variable
export TESTING_WITHOUT_SECRETS=true

# Copy the example environment file
cp .env.test.example .env.test.local

# Run tests with dummy secrets
make test_dummy
```

### For Internal Development

If you have access to real API credentials:

```bash
# Ensure you have real credentials set
export RAILS_MASTER_KEY="your_real_master_key"
export STRIPE_API_KEY="your_real_stripe_key"
# ... other secrets

# Set real secrets mode
export TESTING_WITHOUT_SECRETS=false

# Run tests with real secrets
make test_with_secrets
```

## How It Works

### Automatic Detection

The system automatically detects dummy mode based on:

1. `TESTING_WITHOUT_SECRETS=true` environment variable
2. Presence of dummy values (prefixed with "dummy_")
3. Missing or empty secret values

### Secret Sources

Secrets are resolved in this order:

1. Environment variables
2. Rails encrypted credentials
3. Dummy values (in test mode only)

### Dummy Values

All dummy values follow these patterns:

- API keys: `dummy_[service]_api_key`
- Usernames: `dummy_[service]_username`
- URLs: `https://dummy.[service].test`
- Generic: `dummy_[secret_name]`

## Configuration Files

### Environment Files

- `.env.test` - Default test environment (with dummy secrets)
- `.env.test.example` - Template with all dummy values
- `.env.test.local` - Local overrides (gitignored)

### Key Configuration Files

- `lib/utilities/global_config.rb` - Central configuration with dummy fallbacks
- `spec/support/dummy_secrets_helper.rb` - Dummy mode detection and utilities
- `spec/support/secret_dependent_specs.rb` - Test helpers for conditional execution
- `spec/support/webmock_stubs.rb` - Mock external API responses
- `config/initializers/003_stripe.rb` - Stripe configuration with dummy support

## Writing Tests

### For Tests That Require Real Secrets

```ruby
# Skip test if using dummy secrets
describe "Payment processing", :requires_secrets do
  before { skip_if_missing_secrets("STRIPE_API_KEY", "STRIPE_PLATFORM_ACCOUNT_ID") }
  
  it "processes real payments" do
    # Test implementation
  end
end

# Alternative syntax
describe "Payment processing" do
  it "processes real payments", :real_secrets_only do
    # Test implementation
  end
end
```

### For Tests That Work With Dummy Secrets

```ruby
describe "Payment UI" do
  before { stub_external_service_in_dummy_mode(:stripe) }
  
  it "displays payment form" do
    # This test works with both real and dummy secrets
  end
end
```

### Using Shared Contexts

```ruby
describe "Stripe integration" do
  include_context "with stripe secrets"
  
  it "creates charges" do
    # This test will be skipped if Stripe secrets are dummy
  end
end
```

## External API Mocking

When running in dummy mode, external APIs are automatically mocked:

### Supported Services

- **Stripe**: Payment processing, webhooks, Connect OAuth
- **PayPal**: Payments, IPN verification
- **AWS**: S3, SES
- **Braintree**: Payment processing
- **SendGrid**: Email delivery
- **OAuth Providers**: Google, Discord, Zoom
- **Various APIs**: EasyPost, TaxJar, VATStack, Circle, etc.

### Custom Responses

```ruby
# Test with custom Stripe response
WebMockStubs.with_custom_stripe_response({ error: "Card declined" }) do
  # Test error handling
end

# Test API errors
WebMockStubs.with_api_error(:stripe, 400) do
  # Test error scenarios
end
```

## CI/CD Integration

### GitHub Actions

The workflow automatically uses dummy values when secrets aren't available:

```yaml
env:
  RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY || 'dummy_rails_master_key_for_testing_32b' }}
  STRIPE_API_KEY: ${{ secrets.STRIPE_API_KEY || 'dummy_stripe_secret_key_test' }}
```

### Docker/Make

```bash
# Run tests in Docker with dummy secrets
make test_dummy

# Run tests with real secrets (validates they exist)
make test_with_secrets
```

## VCR Cassettes

### With Dummy Secrets

- New cassettes are recorded for dummy API calls
- Existing cassettes are not filtered for dummy values
- Ensures tests work without real API dependencies

### With Real Secrets

- Sensitive data is filtered from cassettes
- Standard VCR behavior applies
- Real API responses are cached

## Environment Variables

### Core Variables

| Variable | Dummy Value | Purpose |
|----------|-------------|---------|
| `TESTING_WITHOUT_SECRETS` | `true` | Enable dummy mode |
| `RAILS_MASTER_KEY` | `dummy_rails_master_key_for_testing_32b` | Rails credentials |
| `STRIPE_API_KEY` | `dummy_stripe_secret_key_test` | Stripe API |
| `PAYPAL_USERNAME` | `dummy_paypal_username` | PayPal API |
| `AWS_ACCESS_KEY_ID` | `dummy_aws_access_key` | AWS services |

### Payment Processors

| Service | Key Variables |
|---------|---------------|
| Stripe | `STRIPE_API_KEY`, `STRIPE_PLATFORM_ACCOUNT_ID`, `STRIPE_CONNECT_CLIENT_ID` |
| PayPal | `PAYPAL_USERNAME`, `PAYPAL_PASSWORD`, `PAYPAL_SIGNATURE` |
| Braintree | `BRAINTREE_API_PRIVATE_KEY`, `BRAINTREE_MERCHANT_ID` |

### External Services

| Service | Key Variables |
|---------|---------------|
| AWS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| SendGrid | `SENDGRID_*_API_KEY` (multiple keys) |
| TaxJar | `TAXJAR_API_KEY` |
| EasyPost | `EASYPOST_API_KEY` |

## Troubleshooting

### Tests Failing in Dummy Mode

1. **Check if test requires real secrets**:
   ```ruby
   # Add appropriate skip conditions
   skip_if_missing_secrets("REQUIRED_SECRET")
   ```

2. **Verify WebMock stubs are working**:
   ```ruby
   # Add service-specific stubs
   stub_external_service_in_dummy_mode(:service_name)
   ```

3. **Update dummy values if needed**:
   ```ruby
   # Add to GlobalConfig::DUMMY_VALUES hash
   "NEW_SECRET" => "appropriate_dummy_value"
   ```

### VCR Issues

1. **Cassettes not recording**:
   - Ensure `TESTING_WITHOUT_SECRETS=true` is set
   - Check VCR is configured for `:new_episodes` in dummy mode

2. **Real secrets in cassettes**:
   - Verify secrets are properly filtered in `spec_helper.rb`
   - Check secrets don't start with "dummy_"

### CI/CD Issues

1. **GitHub Actions failing**:
   - Verify all secrets have fallback values in workflow
   - Check `continue-on-error: true` for login actions

2. **Docker build issues**:
   - Ensure dummy files are created for missing S3 downloads
   - Verify all required environment variables have defaults

## Contributing

When adding new external service integrations:

1. **Add dummy values** to `GlobalConfig::DUMMY_VALUES`
2. **Add WebMock stubs** in `spec/support/webmock_stubs.rb`
3. **Update environment examples** in `.env.test.example`
4. **Add conditional test helpers** if needed
5. **Test both dummy and real modes** work correctly

## Security Considerations

- Dummy values are clearly marked and non-functional
- Real secrets are never committed to code
- VCR cassettes are sanitized of real credentials
- Dummy mode prevents accidental real API calls during testing

## Migration from Real-Only Testing

To migrate existing tests:

1. **Identify secret dependencies**:
   ```bash
   grep -r "ENV\[" spec/ | grep -E "(API_KEY|SECRET|TOKEN)"
   ```

2. **Add conditional execution**:
   ```ruby
   # Before
   it "calls external API" do
     # test code
   end
   
   # After
   it "calls external API", :requires_secrets do
     skip_if_missing_secrets("API_KEY")
     # test code
   end
   ```

3. **Add WebMock stubs** for external services

4. **Test both modes** work correctly

This approach ensures backward compatibility while enabling broader testing access.