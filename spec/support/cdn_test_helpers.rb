# frozen_string_literal: true

# Helper module to handle CDN URL stubbing in tests
# This ensures tests work correctly with LocalStack URLs in test environment
module CdnTestHelpers
  # Stub CDN URLs to return expected production-like URLs in tests
  # This handles the mismatch between LocalStack URLs and expected CDN URLs
  def stub_cdn_urls_for_tests
    # Stub the cdn_url_for method to properly map LocalStack URLs to CDN URLs
    allow_any_instance_of(CdnUrlHelper).to receive(:cdn_url_for) do |_, url|
      next url if url.nil?
      
      # Map LocalStack URLs to expected CDN URLs
      if url.include?('localhost') && url.include?('gumroad-specs')
        # Replace LocalStack URL with expected CDN URL format
        url.gsub(%r{http://localhost:\d+/gumroad-specs/}, 'https://public-files.gumroad.com/')
      elsif url.include?('localhost') && url.include?('gumroad')
        # Handle other LocalStack bucket URLs
        url.gsub(%r{http://localhost:\d+/gumroad/}, 'https://static-2.gumroad.com/res/gumroad/')
      else
        # Return original URL if no mapping needed
        url
      end
    end
  end

  # Alternative approach: Stub ActiveStorage URLs directly
  def stub_active_storage_cdn_urls
    # Stub blob URLs to return CDN format
    allow_any_instance_of(ActiveStorage::Blob).to receive(:url) do |blob|
      "https://public-files.gumroad.com/#{blob.key}"
    end
    
    # Stub variant URLs
    allow_any_instance_of(ActiveStorage::VariantWithRecord).to receive(:url) do |variant|
      "https://public-files.gumroad.com/#{variant.key}"
    end
  end
end