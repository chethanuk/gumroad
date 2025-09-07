# frozen_string_literal: true

require "spec_helper"

describe CalculateSaleNumbersWorker, :vcr do
  
  
  
  
  before do
    # Ensure Redis is available
    begin
      Redis.new(url: ENV['REDIS_HOST']).ping
    rescue => e
      skip "Redis not available: #{e.message}"
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
  before do
    # Ensure Redis is available
    begin
      Redis.new(url: ENV['REDIS_HOST']).ping
    rescue => e
      skip "Redis not available: #{e.message}"
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
  describe "#perform" do
    it "sets the correct values for `total_made` and `number_of_creators` in Redis" do
      create(:failed_purchase, link: create(:product, price_cents: 99))
      create(:refunded_purchase, link: create(:product, price_cents: 1099))
      create(:free_purchase)
      create(:disputed_purchase, link: create(:product, price_cents: 2099))
      create(:disputed_purchase, chargeback_reversed: true, link: create(:product, price_cents: 3099))
      create(:purchase, link: create(:product, price_cents: 4099))
      create(:purchase, link: create(:product, price_cents: 5099))
      index_model_records(Purchase)

      described_class.new.perform

      expected_total_made_in_usd = (3099 + 4099 + 5099) / 100
      expect($redis.get(RedisKey.number_of_creators)).to eq("3")
      expect($redis.get(RedisKey.total_made)).to eq(expected_total_made_in_usd.to_s)
    end
  end
end
