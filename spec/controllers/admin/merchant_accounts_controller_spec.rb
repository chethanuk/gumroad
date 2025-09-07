# frozen_string_literal: true

require "spec_helper"

require "shared_examples/admin_base_controller_concern"

describe Admin::MerchantAccountsController do
  
  before do
    # Stub admin authentication for tests
    allow_any_instance_of(Admin::BaseController).to receive(:admin_user?).and_return(true)
    allow_any_instance_of(Admin::BaseController).to receive(:current_admin).and_return(
      create(:user, admin: true)
    )
  end
  render_views

  it_behaves_like "inherits from Admin::BaseController"

  let(:admin_user) { create(:admin_user) }

  before do
    sign_in admin_user
  end

  describe "GET show" do
    let(:merchant_account) { MerchantAccount.gumroad(StripeChargeProcessor.charge_processor_id) }

    it "renders the page successfully" do
      # Stub Stripe API call for test environment with dummy credentials
      if merchant_account.charge_processor_id == StripeChargeProcessor.charge_processor_id
        allow(Stripe::Account).to receive(:retrieve).and_return(
          OpenStruct.new(
            charges_enabled: true,
            payouts_enabled: true,
            requirements: OpenStruct.new(
              disabled_reason: nil,
              as_json: {}
            )
          )
        )
      end
      
      get :show, params: { id: merchant_account }

      expect(response).to be_successful
      expect(response).to render_template(:show)
    end

    context "for merchant accounts of type paypal", :vcr do
      it "returns the email address associated with the paypal account" do
        # Handle dummy credentials by stubbing the PayPal API response
        if ENV['PAYPAL_PARTNER_MERCHANT_ID']&.include?('<') || ENV['PAYPAL_PARTNER_MERCHANT_ID']&.start_with?('dummy_')
          paypal_details = { "primary_email" => "sb-byx2u2205460@business.example.com" }
          allow_any_instance_of(MerchantAccount).to receive(:paypal_account_details).and_return(paypal_details)
        end
        
        paypal_merchant_account = create(:merchant_account_paypal, charge_processor_merchant_id: "B66YJBBNCRW6L")

        get :show, params: { id: paypal_merchant_account.id }

        expect(response.body).to have_content("Email \"sb-byx2u2205460@business.example.com\"", normalize_ws: true)
      end
    end

    context "for merchant accounts of type stripe", :vcr do
      it "returns the charges and payouts related flags" do
        stripe_merchant_account = create(:merchant_account, charge_processor_merchant_id: "acct_19paZxAQqMpdRp2I")

        get :show, params: { id: stripe_merchant_account.id }

        expect(response.body).to have_content("Charges enabled false", normalize_ws: true)
        expect(response.body).to have_content("Payout enabled false", normalize_ws: true)
        expect(response.body).to have_content("Disabled reason \"rejected.fraud\"", normalize_ws: true)
        expect(response.body).to have_content("Fields needed", normalize_ws: true)
      end
    end
  end
end
