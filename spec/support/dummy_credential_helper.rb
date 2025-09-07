# frozen_string_literal: true

# Handles tests that require external API credentials
module DummyCredentialHelper
  SERVICE_KEYS = {
    paypal: ['PAYPAL_USERNAME', 'PAYPAL_CLIENT_ID'],
    stripe: ['STRIPE_API_KEY'],
    braintree: ['BRAINTREE_API_PRIVATE_KEY'],
    taxjar: ['TAXJAR_API_KEY'],
    aws: ['AWS_ACCESS_KEY_ID'],
    sendgrid: ['SENDGRID_GUMROAD_TRANSACTIONS_API_KEY'],
    openai: ['OPENAI_ACCESS_TOKEN'],
    vatstack: ['VATSTACK_API_KEY'],
    easypost: ['EASYPOST_API_KEY'],
    circle: ['CIRCLE_API_KEY'],
    discord: ['DISCORD_BOT_TOKEN'],
    zoom: ['ZOOM_CLIENT_ID'],
    cloudfront: ['CLOUDFRONT_KEYPAIR_ID'],
    resend: ['RESEND_API_KEY'],
    helper: ['HELPER_API_KEY'],
    purchasing_power_parity: ['PURCHASING_POWER_PARITY_API_KEY']
  }.freeze
  
  def skip_if_using_dummy_credentials(*services)
    services.each do |service|
      keys = SERVICE_KEYS[service] || ["#{service.to_s.upcase}_API_KEY"]
      skip "Skipping #{service} test - using dummy credentials" if keys.any? { |k| GlobalConfig.using_dummy?(k) }
    end
  end
  
  def vcr_cassette_exists?(name = nil)
    return true if self.class.metadata[:vcr] == true || RSpec.current_example&.metadata&.[](:vcr) == true
    
    name ||= self.class.metadata[:vcr]&.[](:cassette_name) if self.class.metadata[:vcr].is_a?(Hash)
    return false unless name
    
    File.exist?(File.join(VCR.configuration.cassette_library_dir, "#{name}.yml"))
  end
  
  def skip_without_vcr_cassette(*services)
    skip_if_using_dummy_credentials(*services) unless vcr_cassette_exists?
  end
  
  def using_dummy_credentials?
    ENV['TESTING_WITHOUT_SECRETS'] == 'true' ||
      %w[STRIPE_API_KEY PAYPAL_USERNAME BRAINTREE_API_PRIVATE_KEY].any? { |key| GlobalConfig.using_dummy?(key) }
  end
  
  def ensure_test_infrastructure!
    ensure_elasticsearch_indices
    ensure_mongodb_connection
    MerchantAccountTestHelper.ensure_gumroad_merchant_accounts! if using_dummy_credentials? && defined?(MerchantAccountTestHelper)
  end
  
  def localstack_available?
    ENV['LOCALSTACK_ENDPOINT'].present? || ENV['AWS_ENDPOINT_URL'].present?
  end
  
  def skip_without_localstack
    skip "AWS tests require LocalStack or real credentials" if GlobalConfig.using_dummy?('AWS_ACCESS_KEY_ID') && !localstack_available?
  end
  
  def skip_without_ffmpeg
    skip "FFmpeg required for video processing tests" unless system('which ffmpeg > /dev/null 2>&1')
  end
  
  def skip_without_mongodb
    return skip "MongoDB/Mongoid not configured" unless defined?(Mongoid)
    
    begin
      Mongoid.default_client.database_names
    rescue => e
      skip "MongoDB required: #{e.message}"
    end
  end
  
  def skip_without_elasticsearch
    return skip "Elasticsearch not configured" unless defined?(Elasticsearch)
    
    begin
      Product.__elasticsearch__.client.ping if Product.respond_to?(:__elasticsearch__)
    rescue => e
      skip "Elasticsearch required: #{e.message}"
    end
  end
  
  private
  
  def ensure_elasticsearch_indices
    return unless defined?(Elasticsearch)
    
    [Purchase, Product, Balance].compact.each do |model|
      next unless model.respond_to?(:__elasticsearch__)
      begin
        model.__elasticsearch__.client.ping
        model.__elasticsearch__.create_index! force: true
      rescue => e
        Rails.logger.warn "Failed to create Elasticsearch index for #{model}: #{e.message}"
        skip "Elasticsearch not available: #{e.message}" if e.message.include?("Connection refused")
      end
    end
  end
  
  def ensure_mongodb_connection
    return unless defined?(Mongoid)
    
    begin
      Mongoid.default_client.database_names
    rescue => e
      skip "MongoDB not available: #{e.message}"
    end
  end
end