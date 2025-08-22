# frozen_string_literal: true

# Create the shared PayPal merchant accounts
if MerchantAccount.gumroad(PaypalChargeProcessor.charge_processor_id).nil?
  paypal_merchant_account = MerchantAccount.new
  paypal_merchant_account.charge_processor_id = PaypalChargeProcessor.charge_processor_id
  paypal_merchant_account.charge_processor_merchant_id = nil
  
  # Handle dummy credentials properly for testing
  if GlobalConfig.using_dummy?("PAYPAL_USERNAME")
    paypal_merchant_account.charge_processor_merchant_id = "dummy_gumroad_paypal_#{SecureRandom.hex(8)}"
    paypal_merchant_account.charge_processor_alive_at = Time.current
  end
  
  paypal_merchant_account.save!
end
