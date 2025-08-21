# frozen_string_literal: true

# This module provides RSpec shared examples and contexts for handling tests that depend on external secrets
# It ensures tests can run both with dummy secrets (for external contributors) and real secrets (for internal development)
module SecretDependentSpecs
  extend RSpec::SharedContext

  # Shared context for tests requiring Stripe secrets
  shared_context "with stripe secrets", :stripe_secrets do
    before do
      skip_if_missing_secrets("STRIPE_API_KEY", "STRIPE_PLATFORM_ACCOUNT_ID")
    end
  end

  # Shared context for tests requiring PayPal secrets
  shared_context "with paypal secrets", :paypal_secrets do
    before do
      skip_if_missing_secrets("PAYPAL_USERNAME", "PAYPAL_PASSWORD", "PAYPAL_SIGNATURE")
    end
  end

  # Shared context for tests requiring AWS secrets
  shared_context "with aws secrets", :aws_secrets do
    before do
      skip_if_missing_secrets("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
    end
  end

  # Shared context for tests requiring Braintree secrets
  shared_context "with braintree secrets", :braintree_secrets do
    before do
      skip_if_missing_secrets("BRAINTREE_API_PRIVATE_KEY", "BRAINTREE_MERCHANT_ID")
    end
  end

  # Shared context for tests requiring email service secrets
  shared_context "with email secrets", :email_secrets do
    before do
      skip_if_missing_secrets("SENDGRID_GUMROAD_TRANSACTIONS_API_KEY")
    end
  end

  # Shared context for tests requiring external API secrets
  shared_context "with external api secrets", :external_api_secrets do
    before do
      skip_if_missing_secrets("EASYPOST_API_KEY", "VATSTACK_API_KEY", "TAXJAR_API_KEY")
    end
  end

  # Shared context for tests requiring OAuth/social login secrets
  shared_context "with oauth secrets", :oauth_secrets do
    before do
      skip_if_missing_secrets("GOOGLE_CLIENT_ID", "DISCORD_CLIENT_ID")
    end
  end

  # Shared examples for payment processor tests
  shared_examples "payment processor with real secrets" do |processor_name|
    case processor_name
    when :stripe
      include_context "with stripe secrets"
    when :paypal
      include_context "with paypal secrets"
    when :braintree
      include_context "with braintree secrets"
    end

    it "processes payments with real #{processor_name} credentials" do
      # Test implementation should be provided by the including spec
      expect { subject }.not_to raise_error
    end
  end

  # Shared examples for API integration tests
  shared_examples "external api integration" do |api_name|
    before do
      case api_name
      when :stripe
        skip_if_missing_secrets("STRIPE_API_KEY")
      when :paypal
        skip_if_missing_secrets("PAYPAL_USERNAME", "PAYPAL_PASSWORD")
      when :aws
        skip_if_missing_secrets("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
      else
        skip_if_missing_secrets("#{api_name.upcase}_API_KEY")
      end
    end

    it "successfully integrates with #{api_name} API" do
      # Test implementation should be provided by the including spec
      expect { subject }.not_to raise_error
    end
  end

  # Shared examples for webhook tests
  shared_examples "webhook with external verification" do |service_name|
    before do
      case service_name
      when :stripe
        skip_if_missing_secrets("STRIPE_API_KEY")
      when :paypal
        skip_if_missing_secrets("PAYPAL_USERNAME", "PAYPAL_PASSWORD")
      else
        skip_if_dummy_mode
      end
    end

    it "verifies webhook authenticity with #{service_name}" do
      # Test implementation should be provided by the including spec
      expect { subject }.not_to raise_error
    end
  end

  # Helper method to conditionally run tests based on secret availability
  def with_real_secrets_for(*services, &block)
    required_secrets = []
    
    services.each do |service|
      case service
      when :stripe
        required_secrets += %w[STRIPE_API_KEY STRIPE_PLATFORM_ACCOUNT_ID]
      when :paypal
        required_secrets += %w[PAYPAL_USERNAME PAYPAL_PASSWORD PAYPAL_SIGNATURE]
      when :aws
        required_secrets += %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY]
      when :braintree
        required_secrets += %w[BRAINTREE_API_PRIVATE_KEY BRAINTREE_MERCHANT_ID]
      when :email
        required_secrets += %w[SENDGRID_GUMROAD_TRANSACTIONS_API_KEY]
      else
        required_secrets << "#{service.upcase}_API_KEY"
      end
    end

    unless DummySecretsHelper.should_skip_test?(required_secrets)
      block.call
    end
  end

  # Helper method to run tests only with dummy secrets (for testing the dummy infrastructure)
  def with_dummy_secrets_only(&block)
    if DummySecretsHelper.dummy_mode?
      block.call
    else
      skip "Test only runs in dummy secrets mode"
    end
  end

  # Helper method to ensure critical tests still run with real credentials
  def ensure_real_secrets_for(*services)
    required_secrets = []
    
    services.each do |service|
      case service
      when :stripe
        required_secrets += %w[STRIPE_API_KEY]
      when :paypal
        required_secrets += %w[PAYPAL_USERNAME PAYPAL_PASSWORD]
      when :aws
        required_secrets += %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY]
      else
        required_secrets << "#{service.upcase}_API_KEY"
      end
    end

    if DummySecretsHelper.should_skip_test?(required_secrets)
      skip "Critical test requires real secrets for #{services.join(', ')}. Please provide real credentials."
    end
  end

  # Helper to mock external service responses in dummy mode
  def stub_external_service_in_dummy_mode(service, method = :any)
    return unless DummySecretsHelper.dummy_mode?

    case service
    when :stripe
      stub_stripe_requests
    when :paypal
      stub_paypal_requests
    when :aws
      stub_aws_requests
    when :braintree
      stub_braintree_requests
    end
  end

  private

  def stub_stripe_requests
    WebMock.stub_request(:any, /api\.stripe\.com/)
           .to_return(
             status: 200,
             body: { id: "dummy_stripe_response", object: "charge", amount: 1000 }.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end

  def stub_paypal_requests
    WebMock.stub_request(:any, /api\.paypal\.com|api\.sandbox\.paypal\.com/)
           .to_return(
             status: 200,
             body: { status: "SUCCESS", id: "dummy_paypal_transaction" }.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end

  def stub_aws_requests
    WebMock.stub_request(:any, /amazonaws\.com/)
           .to_return(
             status: 200,
             body: "<SuccessResponse></SuccessResponse>",
             headers: { "Content-Type" => "application/xml" }
           )
  end

  def stub_braintree_requests
    WebMock.stub_request(:any, /braintreegateway\.com/)
           .to_return(
             status: 200,
             body: { transaction: { id: "dummy_braintree_transaction", status: "authorized" } }.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end
end

# Include the module in RSpec configuration
RSpec.configure do |config|
  config.include SecretDependentSpecs
  config.extend SecretDependentSpecs
end