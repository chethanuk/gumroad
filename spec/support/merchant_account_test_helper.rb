# frozen_string_literal: true

module MerchantAccountTestHelper
  # Ensures Gumroad's merchant accounts exist for testing with dummy credentials
  def self.ensure_gumroad_merchant_accounts!
    # Only create dummy merchant accounts when using dummy Stripe credentials
    return unless ENV['STRIPE_API_KEY']&.start_with?('dummy_')
    
    # Create Gumroad's Stripe merchant account if it doesn't exist
    stripe_processor_id = StripeChargeProcessor.charge_processor_id
    unless MerchantAccount.where(user_id: nil, charge_processor_id: stripe_processor_id).exists?
      MerchantAccount.create!(
        user_id: nil, # nil means it's Gumroad's account
        charge_processor_id: stripe_processor_id,
        charge_processor_merchant_id: "dummy_gumroad_stripe_#{SecureRandom.hex(8)}",
        charge_processor_alive_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      )
    end
    
    # Create Gumroad's PayPal merchant account if using dummy PayPal credentials
    if ENV['PAYPAL_USERNAME']&.start_with?('dummy_')
      paypal_processor_id = defined?(PaypalChargeProcessor) ? PaypalChargeProcessor.charge_processor_id : "paypal"
      unless MerchantAccount.where(user_id: nil, charge_processor_id: paypal_processor_id).exists?
        MerchantAccount.create!(
          user_id: nil, # nil means it's Gumroad's account
          charge_processor_id: paypal_processor_id,
          charge_processor_merchant_id: "dummy_gumroad_paypal_#{SecureRandom.hex(8)}",
          charge_processor_alive_at: Time.current,
          created_at: Time.current,
          updated_at: Time.current
        )
      end
    end
  end
  
  # Ensures a user has a merchant account for testing
  def self.ensure_user_merchant_account!(user, charge_processor_id: nil)
    charge_processor_id ||= StripeChargeProcessor.charge_processor_id
    return if user.merchant_account(charge_processor_id).present?
    
    # Only create when using dummy credentials
    return unless ENV['STRIPE_API_KEY']&.start_with?('dummy_')
    
    MerchantAccount.create!(
      user: user,
      charge_processor_id: charge_processor_id,
      charge_processor_merchant_id: "dummy_user_#{user.id}_#{charge_processor_id}",
      charge_processor_alive_at: Time.current,
      created_at: Time.current,
      updated_at: Time.current
    )
  end
end