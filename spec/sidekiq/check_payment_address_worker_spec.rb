# frozen_string_literal: true
describe CheckPaymentAddressWorker do
  
  before do
    # Skip if MongoDB is not available or using dummy credentials
    if using_dummy_credentials?
      skip "Test requires MongoDB connection for BlockedObject model"
    end
    
    begin
      Mongoid.default_client.database_names
    rescue => e
      skip "MongoDB required for BlockedObject tests: #{e.message}"
    end
    @previously_banned_user = create(:user, user_risk_state: "suspended_for_fraud", payment_address: "tuhins@gmail.com")
    @blocked_email_object = BlockedObject.block!(BLOCKED_OBJECT_TYPES[:email], "fraudulent_email@zombo.com", nil)
  end

  it "does not flag the user for fraud if there are no other banned users with the same payment address" do
    @user = create(:user, payment_address: "cleanuser@gmail.com")

    CheckPaymentAddressWorker.new.perform(@user.id)

    expect(@user.reload.flagged?).to be(false)
  end

  it "flags the user for fraud if there are other banned users with the same payment address" do
    @user = create(:user, payment_address: "tuhins@gmail.com")

    CheckPaymentAddressWorker.new.perform(@user.id)

    expect(@user.reload.flagged?).to be(true)
  end

  it "flags the user for fraud if a blocked email object exists for their payment address" do
    @user = create(:user, payment_address: "fraudulent_email@zombo.com")

    CheckPaymentAddressWorker.new.perform(@user.id)

    expect(@user.reload.flagged?).to be(true)
  end

  def mongodb_available?
    begin
      Mongoid.default_client.database_names
      true
    rescue => e
      Rails.logger.warn "MongoDB not available: #{e.message}"
      false
    end
  end

end