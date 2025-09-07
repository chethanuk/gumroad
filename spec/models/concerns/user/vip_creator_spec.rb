# frozen_string_literal: true

require "spec_helper"

describe User::VipCreator do
  
  
  before(:all) do
    # Ensure Elasticsearch indices exist
    [Purchase, Product, Balance].each do |model|
      next unless model.respond_to?(:__elasticsearch__)
      begin
        model.__elasticsearch__.create_index! force: true
      rescue => e
        Rails.logger.warn "Failed to create Elasticsearch index: #{e.message}"
      end
    end
  end
  before(:all) do
    # Ensure Elasticsearch indices exist
    [Purchase, Product, Balance].each do |model|
      next unless model.respond_to?(:__elasticsearch__)
      begin
        model.__elasticsearch__.create_index! force: true
      rescue => e
        Rails.logger.warn "Failed to create Elasticsearch index: #{e.message}"
      end
    end
  end
  let(:user) { create(:user) }

  describe "#vip_creator?" do
    context "when gross sales are above $5,000" do
      it "returns true" do
        create(:purchase, link: create(:product, user:, price_cents: 1_00))
        create_list(:purchase, 2, link: create(:product, user:, price_cents: 2500_00))
        index_model_records(Purchase)

        expect(user.vip_creator?).to be true
      end
    end

    context "when gross sales are less than or equal to $5,000" do
      it "returns false" do
        expect(user.sales).to be_empty
        expect(user.vip_creator?).to be false

        create_list(:purchase, 2, link: create(:product, user:, price_cents: 2500_00))
        index_model_records(Purchase)
        expect(user.vip_creator?).to be false
      end
    end
  end
end
