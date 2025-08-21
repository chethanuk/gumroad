# frozen_string_literal: true

# WebMock stubs for external APIs when running tests with dummy secrets
# This ensures tests can run without making actual API calls to external services
module WebMockStubs
  def self.setup_dummy_api_stubs
    return unless DummySecretsHelper.dummy_mode?

    setup_stripe_stubs
    setup_paypal_stubs
    setup_aws_stubs
    setup_braintree_stubs
    setup_sendgrid_stubs
    setup_external_service_stubs
    setup_oauth_stubs
  end

  def self.setup_stripe_stubs
    # Stripe API stubs
    WebMock.stub_request(:any, /api\.stripe\.com/)
           .to_return(
             status: 200,
             body: stripe_success_response.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Stripe Connect OAuth
    WebMock.stub_request(:post, "https://connect.stripe.com/oauth/token")
           .to_return(
             status: 200,
             body: {
               access_token: "sk_test_dummy_token",
               refresh_token: "rt_dummy_token",
               token_type: "bearer",
               stripe_user_id: "acct_dummy_account"
             }.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end

  def self.setup_paypal_stubs
    # PayPal API stubs (both live and sandbox)
    %w[api.paypal.com api.sandbox.paypal.com ipnpb.paypal.com ipnpb.sandbox.paypal.com].each do |host|
      WebMock.stub_request(:any, /#{Regexp.escape(host)}/)
             .to_return(
               status: 200,
               body: paypal_success_response.to_json,
               headers: { "Content-Type" => "application/json" }
             )
    end

    # PayPal IPN verification
    WebMock.stub_request(:post, /ipnpb\.(sandbox\.)?paypal\.com\/cgi-bin\/webscr/)
           .to_return(body: "VERIFIED")
  end

  def self.setup_aws_stubs
    # AWS S3 stubs
    WebMock.stub_request(:any, /s3.*\.amazonaws\.com/)
           .to_return(
             status: 200,
             body: "<SuccessResponse></SuccessResponse>",
             headers: { "Content-Type" => "application/xml" }
           )

    # AWS SES stubs
    WebMock.stub_request(:any, /email.*\.amazonaws\.com/)
           .to_return(
             status: 200,
             body: "<SendEmailResponse></SendEmailResponse>",
             headers: { "Content-Type" => "application/xml" }
           )
  end

  def self.setup_braintree_stubs
    # Braintree API stubs
    WebMock.stub_request(:any, /braintreegateway\.com/)
           .to_return(
             status: 200,
             body: braintree_success_response.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end

  def self.setup_sendgrid_stubs
    # SendGrid API stubs
    WebMock.stub_request(:any, /api\.sendgrid\.com/)
           .to_return(
             status: 202,
             body: "",
             headers: { "Content-Type" => "application/json" }
           )
  end

  def self.setup_external_service_stubs
    # EasyPost API
    WebMock.stub_request(:any, /api\.easypost\.com/)
           .to_return(
             status: 200,
             body: { id: "dummy_easypost_object", object: "address" }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # VATStack API
    WebMock.stub_request(:any, /api\.vatstack\.com/)
           .to_return(
             status: 200,
             body: { valid: true, country_code: "US" }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # TaxJar API
    WebMock.stub_request(:any, /api\.taxjar\.com/)
           .to_return(
             status: 200,
             body: { tax: { amount_to_collect: 0.0 } }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Circle API
    WebMock.stub_request(:any, /api\.circle\.com/)
           .to_return(
             status: 200,
             body: { data: { id: "dummy_circle_payment" } }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Open Exchange Rates API
    WebMock.stub_request(:any, /openexchangerates\.org/)
           .to_return(
             status: 200,
             body: { rates: { "USD" => 1.0, "EUR" => 0.85 } }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Unsplash API
    WebMock.stub_request(:any, /api\.unsplash\.com/)
           .to_return(
             status: 200,
             body: [{ id: "dummy_photo", urls: { regular: "https://dummy.photo.url" } }].to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Dropbox API
    WebMock.stub_request(:any, /api\.dropboxapi\.com/)
           .to_return(
             status: 200,
             body: { entries: [{ ".tag": "file", name: "dummy_file.txt" }] }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # OpenAI API
    WebMock.stub_request(:any, /api\.openai\.com/)
           .to_return(
             status: 200,
             body: {
               choices: [{ message: { content: "This is a dummy AI response for testing." } }]
             }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Slack Webhooks
    WebMock.stub_request(:post, /hooks\.slack\.com/)
           .to_return(status: 200, body: "ok")
  end

  def self.setup_oauth_stubs
    # Google OAuth
    WebMock.stub_request(:any, /oauth2\.googleapis\.com/)
           .to_return(
             status: 200,
             body: {
               access_token: "dummy_google_access_token",
               token_type: "Bearer",
               expires_in: 3600
             }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Discord OAuth
    WebMock.stub_request(:any, /discord\.com\/api/)
           .to_return(
             status: 200,
             body: {
               access_token: "dummy_discord_access_token",
               token_type: "Bearer",
               expires_in: 604800
             }.to_json,
             headers: { "Content-Type" => "application/json" }
           )

    # Zoom OAuth
    WebMock.stub_request(:any, /zoom\.us\/oauth/)
           .to_return(
             status: 200,
             body: {
               access_token: "dummy_zoom_access_token",
               token_type: "Bearer",
               expires_in: 3600
             }.to_json,
             headers: { "Content-Type" => "application/json" }
           )
  end

  # Response templates for different services
  def self.stripe_success_response
    {
      id: "ch_dummy_charge_id",
      object: "charge",
      amount: 1000,
      currency: "usd",
      status: "succeeded",
      paid: true,
      captured: true,
      created: Time.current.to_i,
      customer: "cus_dummy_customer",
      payment_method: "pm_dummy_payment_method"
    }
  end

  def self.paypal_success_response
    {
      id: "dummy_paypal_payment_id",
      status: "COMPLETED",
      amount: {
        total: "10.00",
        currency: "USD"
      },
      create_time: Time.current.iso8601,
      payer: {
        payment_method: "paypal",
        payer_info: {
          email: "buyer@dummy.test"
        }
      }
    }
  end

  def self.braintree_success_response
    {
      transaction: {
        id: "dummy_braintree_transaction",
        status: "authorized",
        type: "sale",
        amount: "10.00",
        currency_iso_code: "USD",
        created_at: Time.current.iso8601,
        customer: {
          id: "dummy_customer_id",
          email: "customer@dummy.test"
        }
      }
    }
  end

  class << self
    # Allow tests to customize stub responses
    def with_custom_stripe_response(custom_response, &block)
      WebMock.stub_request(:any, /api\.stripe\.com/)
             .to_return(
               status: 200,
               body: custom_response.to_json,
               headers: { "Content-Type" => "application/json" }
             )
      block.call
    ensure
      setup_stripe_stubs if DummySecretsHelper.dummy_mode?
    end

    def with_api_error(service, error_status = 400, &block)
      case service
      when :stripe
        WebMock.stub_request(:any, /api\.stripe\.com/)
               .to_return(status: error_status, body: { error: { message: "Test error" } }.to_json)
      when :paypal
        WebMock.stub_request(:any, /api\.paypal\.com/)
               .to_return(status: error_status, body: { error: "Test error" }.to_json)
      end
      
      block.call
    ensure
      setup_dummy_api_stubs if DummySecretsHelper.dummy_mode?
    end
  end
end

# Configure WebMock stubs in test environment
RSpec.configure do |config|
  config.before(:suite) do
    WebMockStubs.setup_dummy_api_stubs if DummySecretsHelper.dummy_mode?
  end

  # Re-setup stubs after each test that might have cleared them
  config.after(:each) do
    WebMockStubs.setup_dummy_api_stubs if DummySecretsHelper.dummy_mode?
  end
end