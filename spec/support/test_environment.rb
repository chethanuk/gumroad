# frozen_string_literal: true

module TestEnvironment
  # Check if we're using LocalStack for S3 operations
  def self.using_localstack?
    ENV['LOCALSTACK_ENDPOINT'].present? || 
    ENV['AWS_ACCESS_KEY_ID']&.start_with?('dummy')
  end
  
  # Check if we're using real AWS credentials
  def self.using_real_aws?
    !using_localstack? && ENV['AWS_ACCESS_KEY_ID'].present? && 
    !ENV['AWS_ACCESS_KEY_ID'].start_with?('dummy')
  end
  
  # Check if we're using dummy credentials
  def self.using_dummy_credentials?
    ENV['STRIPE_API_KEY']&.start_with?('dummy_') ||
    ENV['AWS_ACCESS_KEY_ID']&.start_with?('dummy_')
  end
  
  # Get appropriate S3 storage service based on environment
  def self.s3_storage_service
    if using_localstack?
      :amazon_test
    else
      :amazon
    end
  end
end