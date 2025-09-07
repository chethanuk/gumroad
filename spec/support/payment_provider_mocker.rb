# frozen_string_literal: true

# Comprehensive payment provider mocking for tests with dummy credentials
module PaymentProviderMocker
  extend ActiveSupport::Concern

  included do
    before { mock_payment_providers if should_mock_payment_providers? }
  end

  def should_mock_payment_providers?
    # TESTING_WITHOUT_SECRETS fix: Don't mock when VCR is handling the requests
    return false if RSpec.current_example&.metadata&.[](:vcr)
    ENV['TESTING_WITHOUT_SECRETS'] == 'true'
  end

  def mock_payment_providers
    mock_stripe_api if GlobalConfig.using_dummy?('STRIPE_API_KEY')
    mock_paypal_api if GlobalConfig.using_dummy?('PAYPAL_USERNAME')
    mock_braintree_api if GlobalConfig.using_dummy?('BRAINTREE_API_PRIVATE_KEY')
  end

  def mock_stripe_api
    return unless defined?(Stripe)
    
    # TESTING_WITHOUT_SECRETS fix: Don't mock Stripe when VCR is handling requests
    return if RSpec.current_example&.metadata&.[](:vcr)
    
    # Core Stripe objects
    mock_stripe_object(Stripe::Charge, :charge)
    mock_stripe_object(Stripe::Customer, :customer)
    mock_stripe_object(Stripe::PaymentIntent, :payment_intent)
    mock_stripe_object(Stripe::SetupIntent, :setup_intent)
    mock_stripe_object(Stripe::PaymentMethod, :payment_method)
    mock_stripe_object(Stripe::Account, :account)
    mock_stripe_object(Stripe::Transfer, :transfer)
    mock_stripe_object(Stripe::Payout, :payout)
    
    # Balance operations
    allow(Stripe::Balance).to receive(:retrieve).and_return(stripe_balance_mock)
    allow(Stripe::BalanceTransaction).to receive(:retrieve).and_return(stripe_balance_transaction_mock)
    
    # Special handling for refunds with expanded balance_transaction
    allow(Stripe::Refund).to receive(:create) { |params, *_args| stripe_refund_mock_with_balance_transaction(params) }
    allow(Stripe::Refund).to receive(:retrieve) do |params, *_args|
      # Check if balance_transaction should be expanded
      if params.is_a?(Hash) && params[:expand]&.include?('balance_transaction')
        stripe_refund_mock_with_balance_transaction
      else
        stripe_refund_mock
      end
    end
  end
  
  def mock_paypal_api
    return unless defined?(PayPal::SDK::REST::API)
    
    # TESTING_WITHOUT_SECRETS fix: Don't mock PayPal when VCR is handling requests
    return if RSpec.current_example&.metadata&.[](:vcr)
    
    client = double('PayPal::Client')
    allow(PayPal::SDK::REST::API).to receive(:new).and_return(client)
    
    # PayPal API endpoints
    allow(client).to receive(:post).with(/\/v2\/checkout\/orders/) { paypal_order_response }
    allow(client).to receive(:get).with(/\/v2\/checkout\/orders/) { paypal_order_response(status: 'APPROVED') }
    allow(client).to receive(:post).with(/\/v2\/checkout\/orders\/.*\/capture/) { paypal_capture_response }
    allow(client).to receive(:post).with(/\/v2\/payments\/captures\/.*\/refund/) { paypal_refund_response }
    allow(client).to receive(:post).with(/\/v1\/oauth2\/token/) { paypal_auth_response }
    allow(client).to receive(:post).with(/\/v1\/payments\/payouts/) { paypal_payout_response }
  end
  
  def mock_braintree_api
    return unless defined?(Braintree::Gateway)
    
    # TESTING_WITHOUT_SECRETS fix: Don't mock Braintree when VCR is handling requests
    return if RSpec.current_example&.metadata&.[](:vcr)
    
    gateway = double('Braintree::Gateway')
    allow(Braintree::Gateway).to receive(:new).and_return(gateway)
    
    # Transaction gateway
    transaction_gateway = double('TransactionGateway')
    allow(gateway).to receive(:transaction).and_return(transaction_gateway)
    allow(transaction_gateway).to receive(:sale) { braintree_result(braintree_transaction_mock) }
    allow(transaction_gateway).to receive(:find) { braintree_transaction_mock }
    allow(transaction_gateway).to receive(:refund) { braintree_result(braintree_transaction_mock(status: 'refunded')) }
    
    # Customer gateway
    customer_gateway = double('CustomerGateway')
    allow(gateway).to receive(:customer).and_return(customer_gateway)
    allow(customer_gateway).to receive(:create) { braintree_result(braintree_customer_mock) }
    allow(customer_gateway).to receive(:find) { braintree_customer_mock }
    
    # Client token
    client_token_gateway = double('ClientTokenGateway')
    allow(gateway).to receive(:client_token).and_return(client_token_gateway)
    allow(client_token_gateway).to receive(:generate) { "dummy_braintree_client_token_#{SecureRandom.hex(16)}" }
  end
  
  private
  
  def mock_stripe_object(klass, type)
    allow(klass).to receive(:create) { send("stripe_#{type}_mock") }
    allow(klass).to receive(:retrieve) { send("stripe_#{type}_mock") }
    allow(klass).to receive(:confirm) { send("stripe_#{type}_mock", status: 'succeeded') } if type == :payment_intent
  end
  
  # Stripe mock objects (simplified)
  def stripe_charge_mock(attrs = {})
    Stripe::Charge.construct_from(
      id: "ch_#{SecureRandom.hex(12)}",
      object: 'charge',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      status: attrs[:status] || 'succeeded',
      paid: attrs[:paid] != false,
      refunded: false,
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {},
      destination: attrs[:destination],
      application_fee: attrs[:application_fee]
    )
  end
  
  def stripe_refund_mock(attrs = {})
    Stripe::Refund.construct_from(
      id: "re_#{SecureRandom.hex(12)}",
      object: 'refund',
      amount: attrs[:amount] || 5000,
      charge: attrs[:charge] || "ch_#{SecureRandom.hex(12)}",
      currency: attrs[:currency] || 'usd',
      status: 'succeeded',
      created: Time.now.to_i,
      balance_transaction: attrs[:balance_transaction] || "txn_#{SecureRandom.hex(12)}"
    )
  end
  
  def stripe_customer_mock(attrs = {})
    Stripe::Customer.construct_from(
      id: attrs[:id] || "cus_#{SecureRandom.hex(12)}",
      object: 'customer',
      email: attrs[:email] || "test@example.com",
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {}
    )
  end
  
  def stripe_payment_intent_mock(attrs = {})
    Stripe::PaymentIntent.construct_from(
      id: "pi_#{SecureRandom.hex(12)}",
      object: 'payment_intent',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      status: attrs[:status] || 'requires_payment_method',
      client_secret: "pi_#{SecureRandom.hex(12)}_secret_#{SecureRandom.hex(16)}",
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {}
    )
  end
  
  def stripe_setup_intent_mock(attrs = {})
    Stripe::SetupIntent.construct_from(
      id: "seti_#{SecureRandom.hex(12)}",
      object: 'setup_intent',
      status: attrs[:status] || 'requires_payment_method',
      client_secret: "seti_#{SecureRandom.hex(12)}_secret_#{SecureRandom.hex(16)}",
      created: Time.now.to_i,
      metadata: attrs[:metadata] || {}
    )
  end
  
  def stripe_payment_method_mock(attrs = {})
    Stripe::PaymentMethod.construct_from(
      id: "pm_#{SecureRandom.hex(12)}",
      object: 'payment_method',
      type: 'card',
      customer: attrs[:customer] || "cus_#{SecureRandom.hex(12)}",
      card: {
        brand: 'visa',
        last4: '4242',
        exp_month: 12,
        exp_year: Time.now.year + 2
      },
      created: Time.now.to_i
    )
  end
  
  def stripe_account_mock(attrs = {})
    Stripe::Account.construct_from(
      id: attrs[:id] || "acct_#{SecureRandom.hex(12)}",
      object: 'account',
      type: attrs[:type] || 'standard',
      charges_enabled: true,
      payouts_enabled: true,
      created: Time.now.to_i
    )
  end
  
  def stripe_transfer_mock(attrs = {})
    Stripe::Transfer.construct_from(
      id: "tr_#{SecureRandom.hex(12)}",
      object: 'transfer',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      destination: attrs[:destination] || "acct_#{SecureRandom.hex(12)}",
      created: Time.now.to_i
    )
  end
  
  def stripe_payout_mock(attrs = {})
    Stripe::Payout.construct_from(
      id: "po_#{SecureRandom.hex(12)}",
      object: 'payout',
      amount: attrs[:amount] || 50000,
      currency: attrs[:currency] || 'usd',
      status: attrs[:status] || 'paid',
      created: Time.now.to_i
    )
  end
  
  def stripe_balance_mock
    Stripe::Balance.construct_from(
      object: 'balance',
      available: [{ amount: 100000, currency: 'usd' }],
      pending: [{ amount: 50000, currency: 'usd' }]
    )
  end
  
  def stripe_balance_transaction_mock(attrs = {})
    Stripe::BalanceTransaction.construct_from(
      id: "txn_#{SecureRandom.hex(12)}",
      object: 'balance_transaction',
      amount: attrs[:amount] || 10000,
      currency: attrs[:currency] || 'usd',
      net: attrs[:net] || 9710,
      fee: attrs[:fee] || 290,
      created: Time.now.to_i
    )
  end
  
  def stripe_refund_mock_with_balance_transaction(attrs = {})
    balance_txn = stripe_balance_transaction_mock(amount: attrs[:amount] || 5000)
    refund = stripe_refund_mock(attrs)
    # Override balance_transaction to be the actual object
    refund.instance_variable_set(:@balance_transaction, balance_txn)
    def refund.balance_transaction
      @balance_transaction
    end
    refund
  end
  
  # PayPal mock responses
  def paypal_order_response(attrs = {})
    {
      id: "ORDER-#{SecureRandom.hex(12).upcase}",
      status: attrs[:status] || 'CREATED',
      intent: 'CAPTURE',
      purchase_units: [{ amount: { currency_code: 'USD', value: '100.00' } }],
      create_time: Time.now.iso8601
    }
  end
  
  def paypal_capture_response
    {
      id: "ORDER-#{SecureRandom.hex(12).upcase}",
      status: 'COMPLETED',
      purchase_units: [{
        payments: {
          captures: [{
            id: "CAPTURE-#{SecureRandom.hex(12).upcase}",
            status: 'COMPLETED',
            amount: { currency_code: 'USD', value: '100.00' }
          }]
        }
      }]
    }
  end
  
  def paypal_refund_response
    {
      id: "REFUND-#{SecureRandom.hex(12).upcase}",
      status: 'COMPLETED',
      amount: { currency_code: 'USD', value: '50.00' }
    }
  end
  
  def paypal_auth_response
    {
      access_token: "A21AAI#{SecureRandom.hex(40)}",
      token_type: 'Bearer',
      expires_in: 32400
    }
  end
  
  def paypal_payout_response
    {
      batch_header: {
        payout_batch_id: "PAYOUT-#{SecureRandom.hex(12).upcase}",
        batch_status: 'SUCCESS'
      }
    }
  end
  
  # Braintree mock objects
  def braintree_result(object)
    Braintree::SuccessfulResult.new(object)
  end
  
  def braintree_transaction_mock(attrs = {})
    OpenStruct.new(
      id: SecureRandom.hex(8),
      status: attrs[:status] || 'authorized',
      amount: attrs[:amount] || BigDecimal('100.00'),
      created_at: Time.now,
      processor_response_code: '1000',
      processor_response_text: 'Approved'
    )
  end
  
  def braintree_customer_mock(attrs = {})
    OpenStruct.new(
      id: attrs[:id] || "customer_#{SecureRandom.hex(8)}",
      email: attrs[:email] || 'test@example.com',
      created_at: Time.now
    )
  end
end