# frozen_string_literal: true

# VCR configuration helpers for payment provider testing
module VcrPaymentHelpers
  extend ActiveSupport::Concern
  
  included do
    RSpec.configure do |config|
      config.around(:each, :payment_vcr) do |example|
        configure_payment_vcr(example)
      end
    end if defined?(RSpec)
  end
  
  def configure_payment_vcr(example)
    VCR.use_cassette(
      payment_cassette_name(example),
      vcr_options_for_payment_test
    ) do
      example.run
    end
  rescue VCR::Errors::UnhandledHTTPRequestError => e
    # Fallback to mocks if cassette is missing and using dummy credentials
    if using_dummy_credentials?
      Rails.logger.info "VCR cassette missing, using payment mocks: #{e.message}"
      mock_payment_providers
      example.run
    else
      raise e
    end
  end
  
  private
  
  def payment_cassette_name(example)
    [
      payment_provider_from_metadata(example),
      example.metadata[:file_path].gsub(%r{^spec/|_spec\.rb$}, '').tr('/', '_'),
      example.metadata[:full_description].downcase.gsub(/[^a-z0-9]+/, '_')
    ].compact.join('/')
  end
  
  def payment_provider_from_metadata(example)
    return 'stripe' if example.metadata[:stripe]
    return 'paypal' if example.metadata[:paypal]
    return 'braintree' if example.metadata[:braintree]
    nil
  end
  
  def vcr_options_for_payment_test
    {
      record: vcr_record_mode,
      match_requests_on: [:method, :uri_without_params, :body],
      allow_unused_http_interactions: true,
      allow_playback_repeats: true,
      erb: true
    }
  end
  
  def vcr_record_mode
    return :new_episodes if ENV['VCR_RECORD'] == 'true'
    return :none if ENV['TESTING_WITHOUT_SECRETS'] == 'true'
    :once
  end
  
  def using_dummy_credentials?
    ENV['TESTING_WITHOUT_SECRETS'] == 'true' ||
      GlobalConfig.using_dummy?('STRIPE_API_KEY') ||
      GlobalConfig.using_dummy?('PAYPAL_USERNAME') ||
      GlobalConfig.using_dummy?('BRAINTREE_API_PRIVATE_KEY')
  end
  
  def mock_payment_providers
    # Delegate to PaymentProviderMocker if included
    super if defined?(super)
  end
end