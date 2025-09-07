# frozen_string_literal: true

Braintree::Configuration.environment = Rails.env.production? ? :production : :sandbox

# Handle dummy credentials for testing with VCR
merchant_id = GlobalConfig.get("BRAINTREE_MERCHANT_ID")
public_key = GlobalConfig.get("BRAINTREE_PUBLIC_KEY")
private_key = GlobalConfig.get("BRAINTREE_API_PRIVATE_KEY")

# In test environment with dummy credentials, use fake but valid values
# VCR will intercept these requests and replay recorded responses
if Rails.env.test? && GlobalConfig.using_dummy?("BRAINTREE_MERCHANT_ID")
  # Use fake but valid looking values - VCR will match and replay cassettes
  Braintree::Configuration.merchant_id = "fake_merchant_id"
  Braintree::Configuration.public_key = "fake_public_key"
  Braintree::Configuration.private_key = "fake_private_key"
else
  Braintree::Configuration.merchant_id = merchant_id
  Braintree::Configuration.public_key = public_key
  Braintree::Configuration.private_key = private_key
end
Braintree::Configuration.http_open_timeout = 20
Braintree::Configuration.http_read_timeout = 20

BRAINTREE_MERCHANT_ACCOUNT_ID_FOR_SUPPLIERS = GlobalConfig.get("BRAINTREE_MERCHANT_ACCOUNT_ID_FOR_SUPPLIERS")
