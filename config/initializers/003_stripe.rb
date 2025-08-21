# frozen_string_literal: true

Stripe.api_version = "2023-10-16; risk_in_requirements_beta=v1"
# Ref: https://github.com/gumroad/web/issues/17770, https://stripe.com/docs/rate-limits#object-lock-timeouts
Stripe.max_network_retries = 3

# Determine Stripe public key based on environment
if Rails.env.production?
  STRIPE_PUBLIC_KEY = GlobalConfig.get("STRIPE_PUBLIC_KEY_PROD", "pk_live_Db80xIzLPWhKo1byPrnERmym")
else
  STRIPE_PUBLIC_KEY = GlobalConfig.get("STRIPE_PUBLIC_KEY_TEST", "pk_test_ehGPKw3JPRHYiqEEjgJ02ULC")
end

# Set Stripe API key with fallback for test environments
stripe_api_key = GlobalConfig.get("STRIPE_API_KEY")

# In test environment with dummy secrets, provide a fallback that won't cause initialization errors
if Rails.env.test? && (stripe_api_key.nil? || stripe_api_key&.start_with?("dummy_"))
  stripe_api_key = "sk_test_dummy_key_for_testing_only"
end

Stripe.api_key = stripe_api_key
STRIPE_PLATFORM_ACCOUNT_ID = GlobalConfig.get("STRIPE_PLATFORM_ACCOUNT_ID")
STRIPE_CONNECT_CLIENT_ID = GlobalConfig.get("STRIPE_CONNECT_CLIENT_ID")
STRIPE_SECRET = GlobalConfig.get("STRIPE_API_KEY")
