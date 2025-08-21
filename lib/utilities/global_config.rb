# frozen_string_literal: true

# GlobalConfig provides a centralized way to access environment variables and Rails credentials
class GlobalConfig
  class << self
    # Retrieve a value by its name from environment variables or Rails credentials
    # @param name [String] The name of the environment variable
    # @param default [Object] The default value to return if the value is not found in ENV or credentials
    # @return [String, Object, nil] The value from environment variable, credentials, the default value, or nil if not found and no default provided
    def get(name, default = :__no_default_provided__)
      if default == :__no_default_provided__
        value = ENV.fetch(name, fetch_from_credentials(name))
        # In test environment, provide dummy values for certain secrets if not present
        value = dummy_value_for(name) if value.nil? && Rails.env.test? && should_use_dummy_value?(name)
        value.presence
      else
        ENV.fetch(name, fetch_from_credentials(name) || default)
      end
    end

    # Retrieve a nested value by joining the parts with double underscores
    # @param parts [Array<String>] The parts to join for the environment variable name
    # @param default [Object] The default value to return if the value is not found
    # @return [String, Object, nil] The value from environment variable, credentials, the default value, or nil if not found and no default provided
    def dig(*parts, default: :__no_default_provided__)
      name = parts.map(&:upcase).join("__")
      if default == :__no_default_provided__
        get(name)
      else
        get(name, default)
      end
    end

    private
      # Fetch a value from Rails credentials by converting the environment variable name to credential keys
      # @param name [String] The name of the environment variable
      # @return [Object, nil] The value from credentials or nil if not found
      def fetch_from_credentials(name)
        keys = name.downcase.split("__").map(&:to_sym)
        Rails.application.credentials.dig(*keys)
      end

      # Determines if we should provide a dummy value for the given secret name
      # @param name [String] The name of the environment variable
      # @return [Boolean] true if dummy value should be used
      def should_use_dummy_value?(name)
        return false unless ENV["TESTING_WITHOUT_SECRETS"] == "true"
        
        DUMMY_VALUE_SECRETS.include?(name)
      end

      # Provides a dummy value for a given secret name
      # @param name [String] The name of the environment variable
      # @return [String] Dummy value for the secret
      def dummy_value_for(name)
        DUMMY_VALUES[name] || "dummy_#{name.downcase}"
      end

      # List of secrets that should get dummy values in test mode
      DUMMY_VALUE_SECRETS = %w[
        STRIPE_API_KEY
        STRIPE_PUBLIC_KEY_TEST
        STRIPE_PUBLIC_KEY_PROD
        STRIPE_PLATFORM_ACCOUNT_ID
        STRIPE_CONNECT_CLIENT_ID
        PAYPAL_USERNAME
        PAYPAL_PASSWORD
        PAYPAL_SIGNATURE
        PAYPAL_CLIENT_ID
        PAYPAL_CLIENT_SECRET
        PAYPAL_MERCHANT_EMAIL
        PAYPAL_PARTNER_CLIENT_ID
        PAYPAL_PARTNER_MERCHANT_ID
        PAYPAL_PARTNER_MERCHANT_EMAIL
        PAYPAL_BN_CODE
        BRAINTREE_API_PRIVATE_KEY
        BRAINTREE_MERCHANT_ID
        BRAINTREE_PUBLIC_KEY
        BRAINTREE_MERCHANT_ACCOUNT_ID_FOR_SUPPLIERS
        AWS_ACCESS_KEY_ID
        AWS_SECRET_ACCESS_KEY
        AWS_ACCOUNT_ID
        S3_DELETER_ACCESS_KEY_ID
        S3_DELETER_SECRET_ACCESS_KEY
        SENDGRID_GUMROAD_TRANSACTIONS_API_KEY
        SENDGRID_GR_CREATORS_API_KEY
        SENDGRID_GR_CUSTOMERS_LEVEL_2_API_KEY
        SENDGRID_GUMROAD_FOLLOWER_CONFIRMATION_API_KEY
        EASYPOST_API_KEY
        VATSTACK_API_KEY
        IRAS_API_ID
        IRAS_API_SECRET
        TAXJAR_API_KEY
        TAX_ID_PRO_API_KEY
        CIRCLE_API_KEY
        OPEN_EXCHANGE_RATES_APP_ID
        UNSPLASH_CLIENT_ID
        DROPBOX_API_KEY
        DISCORD_BOT_TOKEN
        DISCORD_CLIENT_ID
        ZOOM_CLIENT_ID
        GCAL_CLIENT_ID
        GOOGLE_CLIENT_ID
        OPENAI_ACCESS_TOKEN
        CLOUDFRONT_KEYPAIR_ID
        SLACK_WEBHOOK_URL
        STRONGBOX_GENERAL_PASSWORD
      ].freeze

      # Predefined dummy values for specific secrets
      DUMMY_VALUES = {
        "STRIPE_API_KEY" => "dummy_stripe_secret_key_test",
        "STRIPE_PUBLIC_KEY_TEST" => "dummy_stripe_public_key_test",
        "STRIPE_PUBLIC_KEY_PROD" => "dummy_stripe_public_key_prod",
        "STRIPE_PLATFORM_ACCOUNT_ID" => "dummy_stripe_platform_account",
        "STRIPE_CONNECT_CLIENT_ID" => "dummy_stripe_connect_client",
        "PAYPAL_USERNAME" => "dummy_paypal_username",
        "PAYPAL_PASSWORD" => "dummy_paypal_password",
        "PAYPAL_SIGNATURE" => "dummy_paypal_signature",
        "PAYPAL_CLIENT_ID" => "dummy_paypal_client_id",
        "PAYPAL_CLIENT_SECRET" => "dummy_paypal_client_secret",
        "PAYPAL_MERCHANT_EMAIL" => "dummy@paypal.test",
        "AWS_ACCESS_KEY_ID" => "dummy_aws_access_key",
        "AWS_SECRET_ACCESS_KEY" => "dummy_aws_secret_key",
        "AWS_ACCOUNT_ID" => "123456789012",
        "SLACK_WEBHOOK_URL" => "https://hooks.slack.com/dummy/webhook/url",
        "STRONGBOX_GENERAL_PASSWORD" => "dummy_password"
      }.freeze
  end
end
