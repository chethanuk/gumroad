# frozen_string_literal: true

# Security-focused payment provider mocking for Gumroad test suite
# Following gumroad-security-engineer patterns for handling sensitive data
module SecurePaymentMocker
  extend self

  # Security: Main entry point with validation
  def mock_all_providers
    validate_test_environment!
    validate_dummy_credentials!
    
    mock_stripe_api
    mock_paypal_api
    mock_braintree_api
    mock_taxjar_api
    
    log_security_status
  end

  # Security validation: Ensure we're in test environment
  def validate_test_environment!
    unless Rails.env.test?
      raise SecurityError, "Payment mocking only allowed in test environment!"
    end
  end

  # Security validation: Ensure no real credentials in test
  def validate_dummy_credentials!
    sensitive_keys = {
      'STRIPE_API_KEY' => /^(sk_live|rk_live)/,
      'PAYPAL_CLIENT_ID' => /^(A[A-Z0-9]{16,})/,
      'BRAINTREE_API_PRIVATE_KEY' => /^[a-f0-9]{32}$/,
      'TAXJAR_API_TOKEN' => /^[a-f0-9]{32}$/
    }
    
    sensitive_keys.each do |key, pattern|
      value = ENV[key]
      next if value.nil? || value.start_with?('dummy_') || value == 'test'
      
      if value.match?(pattern)
        raise SecurityError, "CRITICAL: Real #{key} detected in test! Use dummy_ prefix for test credentials."
      end
    end
  end

  def log_security_status
    Rails.logger.info "[SecurePaymentMocker] Payment providers safely mocked"
    Rails.logger.info "[SecurePaymentMocker] Environment: #{Rails.env}"
    Rails.logger.info "[SecurePaymentMocker] Dummy mode: #{ENV['TESTING_WITHOUT_SECRETS'] == 'true'}"
  end

  # Stripe API mocking with security checks
  def mock_stripe_api
    return unless defined?(Stripe)
    
    # Security: Override API key to prevent real charges
    Stripe.api_key = 'dummy_stripe_sk_test_dummy'
    
    # Mock webhook signature verification
    allow(Stripe::Webhook).to receive(:construct_event).and_wrap_original do |method, *args|
      # Security: Skip signature verification in test
      JSON.parse(args[0], symbolize_names: true)
    end if defined?(Stripe::Webhook)
    
    # Mock all Stripe API objects
    mock_stripe_charges
    mock_stripe_refunds
    mock_stripe_customers
    mock_stripe_payment_intents
    mock_stripe_setup_intents
    mock_stripe_payment_methods
    mock_stripe_accounts
    mock_stripe_transfers
    mock_stripe_payouts
    mock_stripe_disputes
    mock_stripe_webhooks
  end

  def mock_stripe_charges
    return unless defined?(Stripe::Charge)
    
    allow(Stripe::Charge).to receive(:create).and_return(
      stripe_charge_mock(id: "ch_test_#{SecureRandom.hex(12)}")
    )
    allow(Stripe::Charge).to receive(:retrieve) do |id|
      stripe_charge_mock(id: id)
    end
    allow(Stripe::Charge).to receive(:capture) do |id|
      stripe_charge_mock(id: id, captured: true)
    end
  end

  def mock_stripe_refunds
    return unless defined?(Stripe::Refund)
    
    allow(Stripe::Refund).to receive(:create).and_return(
      stripe_refund_mock(id: "re_test_#{SecureRandom.hex(12)}")
    )
    allow(Stripe::Refund).to receive(:retrieve) do |id|
      stripe_refund_mock(id: id)
    end
  end

  def mock_stripe_customers
    return unless defined?(Stripe::Customer)
    
    allow(Stripe::Customer).to receive(:create) do |params|
      stripe_customer_mock(
        id: "cus_test_#{SecureRandom.hex(12)}",
        email: params[:email]
      )
    end
    allow(Stripe::Customer).to receive(:retrieve) do |id|
      stripe_customer_mock(id: id)
    end
    allow(Stripe::Customer).to receive(:update) do |id, params|
      stripe_customer_mock(id: id, email: params[:email])
    end
  end

  def mock_stripe_payment_intents
    return unless defined?(Stripe::PaymentIntent)
    
    allow(Stripe::PaymentIntent).to receive(:create) do |params|
      stripe_payment_intent_mock(
        amount: params[:amount],
        currency: params[:currency],
        metadata: params[:metadata]
      )
    end
    allow(Stripe::PaymentIntent).to receive(:retrieve) do |id|
      stripe_payment_intent_mock(id: id)
    end
    allow(Stripe::PaymentIntent).to receive(:confirm) do |id|
      stripe_payment_intent_mock(id: id, status: 'succeeded')
    end
  end

  def mock_stripe_setup_intents
    return unless defined?(Stripe::SetupIntent)
    
    allow(Stripe::SetupIntent).to receive(:create).and_return(
      stripe_setup_intent_mock
    )
    allow(Stripe::SetupIntent).to receive(:retrieve) do |id|
      stripe_setup_intent_mock(id: id)
    end
  end

  def mock_stripe_payment_methods
    return unless defined?(Stripe::PaymentMethod)
    
    allow(Stripe::PaymentMethod).to receive(:create).and_return(
      stripe_payment_method_mock
    )
    allow(Stripe::PaymentMethod).to receive(:retrieve) do |id|
      stripe_payment_method_mock(id: id)
    end
    allow(Stripe::PaymentMethod).to receive(:attach) do |id, params|
      stripe_payment_method_mock(id: id, customer: params[:customer])
    end
  end

  def mock_stripe_accounts
    return unless defined?(Stripe::Account)
    
    allow(Stripe::Account).to receive(:create) do |params|
      stripe_account_mock(
        id: "acct_test_#{SecureRandom.hex(12)}",
        type: params[:type]
      )
    end
    allow(Stripe::Account).to receive(:retrieve) do |id|
      stripe_account_mock(id: id || 'self')
    end
  end

  def mock_stripe_transfers
    return unless defined?(Stripe::Transfer)
    
    allow(Stripe::Transfer).to receive(:create) do |params|
      stripe_transfer_mock(
        amount: params[:amount],
        destination: params[:destination]
      )
    end
  end

  def mock_stripe_payouts
    return unless defined?(Stripe::Payout)
    
    allow(Stripe::Payout).to receive(:create) do |params|
      stripe_payout_mock(
        amount: params[:amount],
        currency: params[:currency]
      )
    end
  end

  def mock_stripe_disputes
    return unless defined?(Stripe::Dispute)
    
    allow(Stripe::Dispute).to receive(:retrieve) do |id|
      stripe_dispute_mock(id: id)
    end
    allow(Stripe::Dispute).to receive(:update) do |id, params|
      stripe_dispute_mock(id: id, evidence: params[:evidence])
    end
  end

  def mock_stripe_webhooks
    return unless defined?(Stripe::Event)
    
    allow(Stripe::Event).to receive(:retrieve) do |id|
      stripe_event_mock(id: id)
    end
  end

  # PayPal API mocking with security
  def mock_paypal_api
    return unless defined?(PayPal::SDK::REST::API)
    
    # Security: Mock PayPal client with dummy credentials
    client = double('PayPal::Client')
    allow(PayPal::SDK::REST::API).to receive(:new).and_return(client)
    
    # Mock OAuth
    allow(client).to receive(:client_id).and_return('dummy_paypal_client')
    allow(client).to receive(:client_secret).and_return('dummy_paypal_secret')
    
    # Mock API endpoints
    mock_paypal_orders(client)
    mock_paypal_payments(client)
    mock_paypal_payouts(client)
    mock_paypal_webhooks(client)
    mock_paypal_merchant_accounts(client)
  end

  def mock_paypal_orders(client)
    # Create order
    allow(client).to receive(:post).with(/\/v2\/checkout\/orders$/) do
      paypal_order_response(id: "ORDER_TEST_#{SecureRandom.hex(12)}")
    end
    
    # Get order
    allow(client).to receive(:get).with(/\/v2\/checkout\/orders\/[\w-]+$/) do |url|
      order_id = url.split('/').last
      paypal_order_response(id: order_id, status: 'APPROVED')
    end
    
    # Capture order
    allow(client).to receive(:post).with(/\/v2\/checkout\/orders\/[\w-]+\/capture$/) do |url|
      order_id = url.split('/')[-2]
      paypal_capture_response(order_id: order_id)
    end
  end

  def mock_paypal_payments(client)
    # Refund
    allow(client).to receive(:post).with(/\/v2\/payments\/captures\/[\w-]+\/refund$/) do
      paypal_refund_response
    end
    
    # Auth token
    allow(client).to receive(:post).with(/\/v1\/oauth2\/token$/) do
      paypal_auth_response
    end
  end

  def mock_paypal_payouts(client)
    allow(client).to receive(:post).with(/\/v1\/payments\/payouts$/) do
      paypal_payout_response
    end
    
    allow(client).to receive(:get).with(/\/v1\/payments\/payouts\/[\w-]+$/) do
      paypal_payout_status_response
    end
  end

  def mock_paypal_webhooks(client)
    allow(client).to receive(:post).with(/\/v1\/notifications\/verify-webhook-signature$/) do
      { verification_status: 'SUCCESS' }
    end
  end

  def mock_paypal_merchant_accounts(client)
    allow(client).to receive(:get).with(/\/v1\/customer\/partners/) do
      paypal_merchant_status_response
    end
  end

  # Braintree API mocking with security
  def mock_braintree_api
    return unless defined?(Braintree)
    
    # Security: Set sandbox environment with dummy credentials
    Braintree::Configuration.environment = :sandbox
    Braintree::Configuration.merchant_id = 'dummy_merchant_id'
    Braintree::Configuration.public_key = 'dummy_public_key'
    Braintree::Configuration.private_key = 'dummy_private_key'
    
    gateway = double('Braintree::Gateway')
    allow(Braintree::Gateway).to receive(:new).and_return(gateway)
    
    mock_braintree_transactions(gateway)
    mock_braintree_customers(gateway)
    mock_braintree_payment_methods(gateway)
    mock_braintree_disputes(gateway)
    mock_braintree_webhooks(gateway)
  end

  def mock_braintree_transactions(gateway)
    transaction_gateway = double('TransactionGateway')
    allow(gateway).to receive(:transaction).and_return(transaction_gateway)
    
    allow(transaction_gateway).to receive(:sale) do |params|
      braintree_result(
        braintree_transaction_mock(
          amount: params[:amount],
          status: 'authorized'
        )
      )
    end
    
    allow(transaction_gateway).to receive(:find) do |id|
      braintree_transaction_mock(id: id)
    end
    
    allow(transaction_gateway).to receive(:refund) do |id, amount|
      braintree_result(
        braintree_transaction_mock(
          id: "refund_#{id}",
          amount: amount,
          status: 'refunded'
        )
      )
    end
    
    allow(transaction_gateway).to receive(:submit_for_settlement) do |id|
      braintree_result(
        braintree_transaction_mock(id: id, status: 'settling')
      )
    end
  end

  def mock_braintree_customers(gateway)
    customer_gateway = double('CustomerGateway')
    allow(gateway).to receive(:customer).and_return(customer_gateway)
    
    allow(customer_gateway).to receive(:create) do |params|
      braintree_result(
        braintree_customer_mock(
          email: params[:email],
          id: "cust_test_#{SecureRandom.hex(8)}"
        )
      )
    end
    
    allow(customer_gateway).to receive(:find) do |id|
      braintree_customer_mock(id: id)
    end
  end

  def mock_braintree_payment_methods(gateway)
    payment_method_gateway = double('PaymentMethodGateway')
    allow(gateway).to receive(:payment_method).and_return(payment_method_gateway)
    
    allow(payment_method_gateway).to receive(:create) do |params|
      braintree_result(
        braintree_payment_method_mock(
          customer_id: params[:customer_id],
          token: "token_test_#{SecureRandom.hex(8)}"
        )
      )
    end
  end

  def mock_braintree_disputes(gateway)
    dispute_gateway = double('DisputeGateway')
    allow(gateway).to receive(:dispute).and_return(dispute_gateway)
    
    allow(dispute_gateway).to receive(:find) do |id|
      braintree_dispute_mock(id: id)
    end
    
    allow(dispute_gateway).to receive(:add_evidence) do |id, evidence|
      braintree_result(braintree_dispute_mock(id: id))
    end
  end

  def mock_braintree_webhooks(gateway)
    webhook_notification_gateway = double('WebhookNotificationGateway')
    allow(gateway).to receive(:webhook_notification).and_return(webhook_notification_gateway)
    
    allow(webhook_notification_gateway).to receive(:parse) do |signature, payload|
      braintree_webhook_notification_mock
    end
  end

  # TaxJar API mocking
  def mock_taxjar_api
    return unless defined?(Taxjar)
    
    client = double('Taxjar::Client')
    allow(Taxjar::Client).to receive(:new).and_return(client)
    
    # Tax calculation
    allow(client).to receive(:tax_for_order) do |params|
      taxjar_tax_response(params)
    end
    
    # Rates lookup
    allow(client).to receive(:rates_for_location) do |zip|
      taxjar_rates_response(zip)
    end
    
    # Transaction recording
    allow(client).to receive(:create_order) do |params|
      taxjar_order_response(params)
    end
    
    allow(client).to receive(:create_refund) do |params|
      taxjar_refund_response(params)
    end
  end

  private

  # Stripe mock objects with security considerations
  def stripe_charge_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "ch_test_#{SecureRandom.hex(12)}",
      object: 'charge',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      status: attrs[:status] || 'succeeded',
      paid: attrs[:paid] != false,
      captured: attrs[:captured] != false,
      refunded: attrs[:refunded] || false,
      disputed: attrs[:disputed] || false,
      fraud_details: {},
      outcome: {
        network_status: 'approved_by_network',
        risk_level: 'normal',
        risk_score: 10,
        type: 'authorized'
      },
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false # Security: Always false in test
    )
  end

  def stripe_refund_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "re_test_#{SecureRandom.hex(12)}",
      object: 'refund',
      amount: attrs[:amount] || 5000,
      charge: attrs[:charge] || "ch_test_#{SecureRandom.hex(12)}",
      currency: attrs[:currency] || 'usd',
      status: 'succeeded',
      reason: attrs[:reason] || 'requested_by_customer',
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_customer_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "cus_test_#{SecureRandom.hex(12)}",
      object: 'customer',
      email: attrs[:email] || "test@example.com",
      description: attrs[:description],
      default_source: attrs[:default_source],
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_payment_intent_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "pi_test_#{SecureRandom.hex(12)}",
      object: 'payment_intent',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      status: attrs[:status] || 'requires_payment_method',
      client_secret: "pi_test_secret_#{SecureRandom.hex(16)}",
      payment_method: attrs[:payment_method],
      charges: OpenStruct.new(data: []),
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_setup_intent_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "seti_test_#{SecureRandom.hex(12)}",
      object: 'setup_intent',
      status: attrs[:status] || 'requires_payment_method',
      client_secret: "seti_test_secret_#{SecureRandom.hex(16)}",
      payment_method: attrs[:payment_method],
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_payment_method_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "pm_test_#{SecureRandom.hex(12)}",
      object: 'payment_method',
      type: 'card',
      card: OpenStruct.new(
        brand: 'visa',
        last4: '4242',
        exp_month: 12,
        exp_year: Time.now.year + 2,
        fingerprint: SecureRandom.hex(16)
      ),
      customer: attrs[:customer],
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_account_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "acct_test_#{SecureRandom.hex(12)}",
      object: 'account',
      type: attrs[:type] || 'standard',
      charges_enabled: true,
      payouts_enabled: true,
      requirements: OpenStruct.new(
        currently_due: [],
        eventually_due: [],
        past_due: [],
        pending_verification: []
      ),
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {}
    )
  end

  def stripe_transfer_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "tr_test_#{SecureRandom.hex(12)}",
      object: 'transfer',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      destination: attrs[:destination] || "acct_test_#{SecureRandom.hex(12)}",
      destination_payment: "py_test_#{SecureRandom.hex(12)}",
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_payout_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "po_test_#{SecureRandom.hex(12)}",
      object: 'payout',
      amount: attrs[:amount] || 50000,
      currency: attrs[:currency] || 'usd',
      status: attrs[:status] || 'paid',
      method: 'standard',
      destination: attrs[:destination] || 'ba_test_#{SecureRandom.hex(12)}',
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_dispute_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "dp_test_#{SecureRandom.hex(12)}",
      object: 'dispute',
      amount: attrs[:amount] || 10000,
      charge: attrs[:charge] || "ch_test_#{SecureRandom.hex(12)}",
      currency: 'usd',
      reason: attrs[:reason] || 'fraudulent',
      status: attrs[:status] || 'warning_needs_response',
      evidence: attrs[:evidence] || OpenStruct.new,
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      livemode: false
    )
  end

  def stripe_event_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "evt_test_#{SecureRandom.hex(12)}",
      object: 'event',
      type: attrs[:type] || 'charge.succeeded',
      data: OpenStruct.new(
        object: stripe_charge_mock
      ),
      created: Time.now.to_i,
      livemode: false
    )
  end

  # PayPal mock responses with security
  def paypal_order_response(attrs = {})
    {
      id: attrs[:id] || "ORDER_TEST_#{SecureRandom.hex(12).upcase}",
      status: attrs[:status] || 'CREATED',
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: 'default',
        amount: {
          currency_code: attrs[:currency] || 'USD',
          value: attrs[:amount] || '100.00'
        }
      }],
      create_time: Time.now.iso8601,
      links: [
        { rel: 'self', href: '/v2/checkout/orders/' + attrs[:id] },
        { rel: 'approve', href: 'https://www.sandbox.paypal.com/checkoutnow' }
      ]
    }
  end

  def paypal_capture_response(attrs = {})
    {
      id: attrs[:order_id] || "ORDER_TEST_#{SecureRandom.hex(12).upcase}",
      status: 'COMPLETED',
      purchase_units: [{
        reference_id: 'default',
        payments: {
          captures: [{
            id: "CAPTURE_TEST_#{SecureRandom.hex(12).upcase}",
            status: 'COMPLETED',
            amount: {
              currency_code: 'USD',
              value: '100.00'
            },
            final_capture: true,
            create_time: Time.now.iso8601
          }]
        }
      }]
    }
  end

  def paypal_refund_response(attrs = {})
    {
      id: "REFUND_TEST_#{SecureRandom.hex(12).upcase}",
      status: 'COMPLETED',
      amount: {
        currency_code: attrs[:currency] || 'USD',
        value: attrs[:amount] || '50.00'
      },
      create_time: Time.now.iso8601
    }
  end

  def paypal_auth_response
    {
      scope: 'https://api.paypal.com/v1/payments/.* https://api.paypal.com/v1/vault/.*',
      access_token: "A21AAI_TEST_#{SecureRandom.hex(40)}",
      token_type: 'Bearer',
      app_id: 'APP-TEST-80W284485P519543T',
      expires_in: 32400,
      nonce: SecureRandom.hex(40)
    }
  end

  def paypal_payout_response
    {
      batch_header: {
        sender_batch_header: {
          sender_batch_id: "batch_test_#{SecureRandom.hex(8)}",
          email_subject: 'You have a payout!',
          email_message: 'You have received a payout!'
        },
        payout_batch_id: "PAYOUT_TEST_#{SecureRandom.hex(12).upcase}",
        batch_status: 'PENDING'
      }
    }
  end

  def paypal_payout_status_response
    {
      batch_header: {
        payout_batch_id: "PAYOUT_TEST_#{SecureRandom.hex(12).upcase}",
        batch_status: 'SUCCESS',
        time_completed: Time.now.iso8601
      },
      items: [{
        payout_item_id: "ITEM_TEST_#{SecureRandom.hex(12).upcase}",
        transaction_status: 'SUCCESS'
      }]
    }
  end

  def paypal_merchant_status_response
    {
      merchant_id: "MERCHANT_TEST_#{SecureRandom.hex(12).upcase}",
      tracking_id: SecureRandom.hex(16),
      products: [{
        name: 'PPCP',
        status: 'ACTIVE'
      }],
      capabilities: [{
        name: 'CUSTOM_CARD_PROCESSING',
        status: 'ACTIVE'
      }]
    }
  end

  # Braintree mock objects with security
  def braintree_result(object)
    OpenStruct.new(
      success?: true,
      transaction: object,
      customer: object,
      payment_method: object
    )
  end

  def braintree_transaction_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "txn_test_#{SecureRandom.hex(8)}",
      status: attrs[:status] || 'authorized',
      type: 'sale',
      amount: attrs[:amount] || BigDecimal('100.00'),
      currency_iso_code: attrs[:currency] || 'USD',
      merchant_account_id: 'dummy_merchant_account',
      processor_response_code: '1000',
      processor_response_text: 'Approved',
      created_at: Time.now,
      updated_at: Time.now,
      gateway_rejection_reason: nil,
      risk_data: OpenStruct.new(
        id: SecureRandom.hex(8),
        decision: 'Not Evaluated'
      )
    )
  end

  def braintree_customer_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "cust_test_#{SecureRandom.hex(8)}",
      email: attrs[:email] || 'test@example.com',
      first_name: attrs[:first_name],
      last_name: attrs[:last_name],
      created_at: Time.now,
      updated_at: Time.now,
      payment_methods: []
    )
  end

  def braintree_payment_method_mock(attrs = {})
    OpenStruct.new(
      token: attrs[:token] || "token_test_#{SecureRandom.hex(8)}",
      customer_id: attrs[:customer_id],
      card_type: 'Visa',
      last_4: '1111',
      expiration_month: '12',
      expiration_year: (Time.now.year + 2).to_s,
      created_at: Time.now,
      updated_at: Time.now
    )
  end

  def braintree_dispute_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "dispute_test_#{SecureRandom.hex(8)}",
      amount: attrs[:amount] || BigDecimal('100.00'),
      currency_iso_code: 'USD',
      reason: attrs[:reason] || 'fraud',
      status: attrs[:status] || 'open',
      received_date: Date.today,
      reply_by_date: Date.today + 7.days,
      transaction: braintree_transaction_mock
    )
  end

  def braintree_webhook_notification_mock
    OpenStruct.new(
      kind: Braintree::WebhookNotification::Kind::DisputeOpened,
      timestamp: Time.now,
      dispute: braintree_dispute_mock
    )
  end

  # TaxJar mock responses
  def taxjar_tax_response(params)
    OpenStruct.new(
      order_total_amount: params[:amount] || 100.00,
      shipping: params[:shipping] || 0.00,
      taxable_amount: params[:amount] || 100.00,
      amount_to_collect: calculate_mock_tax(params[:amount] || 100.00),
      rate: 0.0875,
      has_nexus: true,
      freight_taxable: false,
      tax_source: 'destination',
      jurisdictions: OpenStruct.new(
        country: 'US',
        state: params[:to_state] || 'CA',
        county: 'LOS ANGELES',
        city: 'LOS ANGELES'
      ),
      breakdown: OpenStruct.new(
        taxable_amount: params[:amount] || 100.00,
        tax_collectable: calculate_mock_tax(params[:amount] || 100.00),
        combined_tax_rate: 0.0875,
        state_taxable_amount: params[:amount] || 100.00,
        state_tax_rate: 0.0625,
        state_tax_collectable: (params[:amount] || 100.00) * 0.0625,
        county_taxable_amount: params[:amount] || 100.00,
        county_tax_rate: 0.025,
        county_tax_collectable: (params[:amount] || 100.00) * 0.025
      )
    )
  end

  def taxjar_rates_response(zip)
    OpenStruct.new(
      zip: zip,
      country: 'US',
      country_rate: 0.0,
      state: 'CA',
      state_rate: 0.0625,
      county: 'LOS ANGELES',
      county_rate: 0.025,
      city: 'LOS ANGELES',
      city_rate: 0.0,
      combined_district_rate: 0.0,
      combined_rate: 0.0875,
      freight_taxable: false
    )
  end

  def taxjar_order_response(params)
    OpenStruct.new(
      transaction_id: params[:transaction_id] || "order_test_#{SecureRandom.hex(8)}",
      user_id: params[:customer_id],
      transaction_date: params[:transaction_date] || Date.today.to_s,
      to_country: 'US',
      to_state: params[:to_state] || 'CA',
      to_zip: params[:to_zip] || '90210',
      amount: params[:amount] || 100.00,
      shipping: params[:shipping] || 0.00,
      sales_tax: calculate_mock_tax(params[:amount] || 100.00)
    )
  end

  def taxjar_refund_response(params)
    OpenStruct.new(
      transaction_id: params[:transaction_id] || "refund_test_#{SecureRandom.hex(8)}",
      user_id: params[:customer_id],
      transaction_date: params[:transaction_date] || Date.today.to_s,
      transaction_reference_id: params[:transaction_reference_id],
      to_country: 'US',
      to_state: params[:to_state] || 'CA',
      to_zip: params[:to_zip] || '90210',
      amount: params[:amount] || 50.00,
      shipping: params[:shipping] || 0.00,
      sales_tax: calculate_mock_tax(params[:amount] || 50.00)
    )
  end

  def calculate_mock_tax(amount)
    (amount * 0.0875).round(2)
  end
end