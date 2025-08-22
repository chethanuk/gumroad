# frozen_string_literal: true

# Create the shared Braintree merchant accounts
if MerchantAccount.gumroad(BraintreeChargeProcessor.charge_processor_id).nil?
  merchant_account_braintree = MerchantAccount.new
  merchant_account_braintree.charge_processor_id = BraintreeChargeProcessor.charge_processor_id
  merchant_account_braintree.charge_processor_merchant_id = BRAINTREE_MERCHANT_ACCOUNT_ID_FOR_SUPPLIERS
  
  # Handle dummy credentials properly for testing
  if GlobalConfig.using_dummy?("BRAINTREE_API_PRIVATE_KEY")
    merchant_account_braintree.charge_processor_alive_at = Time.current
  end
  
  merchant_account_braintree.save!
end
