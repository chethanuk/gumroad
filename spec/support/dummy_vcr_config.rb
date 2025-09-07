# frozen_string_literal: true

# Configuration for VCR when using dummy credentials
# Prevents external API calls and handles placeholder substitution
module DummyVCRConfig
  def self.configure!
    return unless Rails.env.test?
    return unless using_dummy_credentials?
    
    Rails.logger.info "Configuring VCR for dummy credentials mode" if defined?(Rails.logger)
    
    VCR.configure do |c|
      # Replace placeholders in request URIs before playback
      c.before_playback do |interaction|
        sanitize_interaction!(interaction)
      end
      
      # Prevent any external HTTP calls when using dummy credentials
      c.before_http_request do |request|
        if contains_dummy_or_placeholder?(request.uri.to_s)
          # Allow the request to be handled by VCR cassettes or stubs
          # but log it for debugging
          Rails.logger.debug "VCR: Intercepting request with dummy credentials to: #{request.uri}" if defined?(Rails.logger)
        end
      end
      
      # Filter sensitive data more aggressively in dummy mode
      c.filter_sensitive_data('<DUMMY_CREDENTIAL>') do |interaction|
        interaction.request.headers['Authorization']&.first if interaction.request.headers['Authorization']
      end
    end
  end
  
  private
  
  def self.using_dummy_credentials?
    ENV.values.any? { |v| v.to_s.start_with?('dummy_') || v.to_s.start_with?('test_') }
  end
  
  def self.contains_dummy_or_placeholder?(string)
    string.include?('dummy_') || 
    string.include?('test_') || 
    string.match?(/<[A-Z_]+>/)
  end
  
  def self.sanitize_interaction!(interaction)
    # Replace placeholder patterns in URIs
    if interaction.request.uri.include?('<')
      original_uri = interaction.request.uri
      sanitized_uri = original_uri.gsub(/<[A-Z_]+>/, 'dummy_value')
      
      # Update the URI if it changed
      if original_uri != sanitized_uri
        interaction.request.uri = sanitized_uri
        Rails.logger.debug "VCR: Sanitized URI from #{original_uri} to #{sanitized_uri}" if defined?(Rails.logger)
      end
    end
    
    # Also sanitize the request body if present
    if interaction.request.body && interaction.request.body.include?('<')
      interaction.request.body = interaction.request.body.gsub(/<[A-Z_]+>/, 'dummy_value')
    end
  end
end