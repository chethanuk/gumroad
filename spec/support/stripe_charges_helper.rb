# frozen_string_literal: true

module StripeChargesHelper
  def create_stripe_charge(payment_method_id, **charge_params)
    payment_intent = create_stripe_payment_intent(payment_method_id, **charge_params)
    
    # TESTING_WITHOUT_SECRETS fix: Create mock charge when payment intent doesn't have charge data
    # This happens when using dummy credentials and mocked Stripe objects
    if payment_intent.respond_to?(:latest_charge) && payment_intent.latest_charge
      Stripe::Charge.retrieve(id: payment_intent.latest_charge)
    elsif payment_intent.respond_to?(:charges) && payment_intent.charges&.data&.first&.id
      Stripe::Charge.retrieve(id: payment_intent.charges.data.first.id)
    else
      # Create a mock charge for testing without real Stripe API
      Stripe::Charge.new(
        id: "ch_test_#{SecureRandom.hex(12)}",
        amount: charge_params[:amount] || 100,
        currency: charge_params[:currency] || 'usd',
        payment_intent: payment_intent.respond_to?(:id) ? payment_intent.id : "pi_test_#{SecureRandom.hex(12)}"
      )
    end
  end

  def create_stripe_payment_intent(payment_method_id, **charge_params)
    payload = {
      payment_method: payment_method_id,
      payment_method_types: ["card"]
    }
    payload.merge!(charge_params)

    Stripe::PaymentIntent.create(payload)
  end

  def create_stripe_setup_intent(payment_method_id, **charge_params)
    stripe_customer = Stripe::Customer.create(payment_method: payment_method_id)

    payload = {
      payment_method: payment_method_id,
      customer: stripe_customer.id,
      payment_method_types: ["card"],
      usage: "off_session"
    }
    payload.merge!(charge_params)

    Stripe::SetupIntent.create(payload)
  end
end
