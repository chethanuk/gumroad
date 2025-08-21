# frozen_string_literal: true

# DummySecretsHelper provides utilities for managing dummy secrets in test environments
# This allows tests to run without requiring real API credentials
module DummySecretsHelper
  # Detects if we're running in dummy secrets mode
  # @return [Boolean] true if using dummy secrets, false if using real secrets
  def self.dummy_mode?
    @dummy_mode ||= ENV["TESTING_WITHOUT_SECRETS"] == "true" || using_dummy_secrets?
  end

  # Checks if current environment appears to be using dummy secrets
  # @return [Boolean] true if dummy secrets are detected
  def self.using_dummy_secrets?
    dummy_indicators = [
      ENV["STRIPE_API_KEY"]&.start_with?("dummy_"),
      ENV["RAILS_MASTER_KEY"] == "dummy_rails_master_key_for_testing_32b",
      ENV["PAYPAL_USERNAME"]&.start_with?("dummy_"),
      ENV["AWS_ACCESS_KEY_ID"]&.start_with?("dummy_")
    ]
    dummy_indicators.any?
  end

  # Determines if a test should be skipped due to missing real secrets
  # @param required_secrets [Array<String>] List of environment variable names required for the test
  # @return [Boolean] true if test should be skipped
  def self.should_skip_test?(required_secrets)
    return false unless dummy_mode?

    required_secrets.any? { |secret| secret_is_dummy?(secret) }
  end

  # Checks if a specific secret appears to be a dummy value
  # @param secret_name [String] Environment variable name
  # @return [Boolean] true if the secret appears to be dummy
  def self.secret_is_dummy?(secret_name)
    value = ENV[secret_name]
    return true if value.nil? || value.empty?
    return true if value.start_with?("dummy_", "test_")
    return true if KNOWN_DUMMY_VALUES.include?(value)

    false
  end

  # List of known dummy values that should be considered non-functional
  KNOWN_DUMMY_VALUES = [
    "dummy_rails_master_key_for_testing_32b",
    "dummy_stripe_secret_key_test",
    "dummy_paypal_username",
    "dummy_aws_access_key",
    "dummy_knapsack_token",
    "dummy_buildkite_token",
    "dummy_contribsys_credentials"
  ].freeze

  # Returns appropriate dummy value for a given secret type
  # @param secret_type [Symbol] Type of secret (:stripe, :paypal, :aws, etc.)
  # @return [String] Dummy value for the secret type
  def self.dummy_value_for(secret_type)
    case secret_type
    when :stripe_api_key
      "dummy_stripe_secret_key_test"
    when :stripe_public_key
      "dummy_stripe_public_key_test"
    when :paypal_username
      "dummy_paypal_username"
    when :paypal_password
      "dummy_paypal_password"
    when :aws_access_key
      "dummy_aws_access_key"
    when :aws_secret_key
      "dummy_aws_secret_key"
    when :rails_master_key
      "dummy_rails_master_key_for_testing_32b"
    else
      "dummy_#{secret_type}"
    end
  end

  # Creates a hash of environment variables with dummy values
  # @return [Hash] Environment variables with dummy values
  def self.dummy_env_vars
    {
      "STRIPE_API_KEY" => dummy_value_for(:stripe_api_key),
      "STRIPE_PUBLIC_KEY_TEST" => dummy_value_for(:stripe_public_key),
      "PAYPAL_USERNAME" => dummy_value_for(:paypal_username),
      "PAYPAL_PASSWORD" => dummy_value_for(:paypal_password),
      "AWS_ACCESS_KEY_ID" => dummy_value_for(:aws_access_key),
      "AWS_SECRET_ACCESS_KEY" => dummy_value_for(:aws_secret_key),
      "RAILS_MASTER_KEY" => dummy_value_for(:rails_master_key),
      "TESTING_WITHOUT_SECRETS" => "true"
    }
  end

  # RSpec helper methods
  module RSpecHelpers
    # Skips current test if required secrets are not available
    # @param secrets [Array<String>, String] Required secret names
    def skip_if_missing_secrets(*secrets)
      secrets = Array(secrets).flatten
      if DummySecretsHelper.should_skip_test?(secrets)
        skip "Test requires real secrets: #{secrets.join(', ')}. Set TESTING_WITHOUT_SECRETS=false to run with real secrets."
      end
    end

    # Skips current test if in dummy mode
    def skip_if_dummy_mode
      if DummySecretsHelper.dummy_mode?
        skip "Test skipped in dummy secrets mode. Set TESTING_WITHOUT_SECRETS=false to run with real secrets."
      end
    end

    # Runs test only if real secrets are available
    # @param secrets [Array<String>, String] Required secret names
    def with_real_secrets(*secrets, &block)
      secrets = Array(secrets).flatten
      if DummySecretsHelper.should_skip_test?(secrets)
        skip "Test requires real secrets: #{secrets.join(', ')}"
      else
        block.call
      end
    end

    # Configures test environment with dummy values
    def with_dummy_secrets(&block)
      original_env = {}
      DummySecretsHelper.dummy_env_vars.each do |key, value|
        original_env[key] = ENV[key]
        ENV[key] = value
      end

      begin
        block.call
      ensure
        original_env.each do |key, value|
          if value.nil?
            ENV.delete(key)
          else
            ENV[key] = value
          end
        end
      end
    end
  end
end

# Include helper methods in RSpec
RSpec.configure do |config|
  config.include DummySecretsHelper::RSpecHelpers

  # Add metadata for secret-dependent tests
  config.before(:each, :requires_secrets) do |example|
    required_secrets = example.metadata[:requires_secrets]
    required_secrets = [required_secrets] unless required_secrets.is_a?(Array)
    skip_if_missing_secrets(required_secrets)
  end

  # Add metadata for tests that should only run with real secrets
  config.before(:each, :real_secrets_only) do
    skip_if_dummy_mode
  end
end