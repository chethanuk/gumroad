# frozen_string_literal: true

# Create the shared Stripe merchant account
if MerchantAccount.gumroad(StripeChargeProcessor.charge_processor_id).nil?
  merchant_account_stripe = MerchantAccount.new
  merchant_account_stripe.charge_processor_id = StripeChargeProcessor.charge_processor_id
  
  # Handle dummy credentials properly for testing
  if GlobalConfig.using_dummy?("STRIPE_API_KEY")
    merchant_account_stripe.charge_processor_merchant_id = "dummy_gumroad_stripe_#{SecureRandom.hex(8)}"
    merchant_account_stripe.charge_processor_alive_at = Time.current
  end
  
  merchant_account_stripe.save!
end
