# frozen_string_literal: true

# Helper module for stubbing GeoIP lookups in tests
# Provides consistent defaults and easy-to-use stubbing methods
module GeoipHelpers
  # Default GeoIP data for common test scenarios
  DEFAULT_GEOIP_DATA = {
    # United States (default)
    us: {
      country_name: "United States",
      country_code: "US",
      region_name: "CA",
      city_name: "San Francisco",
      postal_code: "94110",
      latitude: 37.7749,
      longitude: -122.4194
    },
    # Canada
    canada: {
      country_name: "Canada",
      country_code: "CA",
      region_name: "ON",
      city_name: "Toronto",
      postal_code: "M5V 3A8",
      latitude: 43.6532,
      longitude: -79.3832
    },
    # France
    france: {
      country_name: "France",
      country_code: "FR",
      region_name: "IDF",
      city_name: "Paris",
      postal_code: "75001",
      latitude: 48.8566,
      longitude: 2.3522
    },
    # United Kingdom
    uk: {
      country_name: "United Kingdom",
      country_code: "GB",
      region_name: "ENG",
      city_name: "London",
      postal_code: "SW1A 1AA",
      latitude: 51.5074,
      longitude: -0.1278
    },
    # Germany
    germany: {
      country_name: "Germany",
      country_code: "DE",
      region_name: "BE",
      city_name: "Berlin",
      postal_code: "10115",
      latitude: 52.5200,
      longitude: 13.4050
    },
    # Japan
    japan: {
      country_name: "Japan",
      country_code: "JP",
      region_name: "13",
      city_name: "Tokyo",
      postal_code: "100-0001",
      latitude: 35.6762,
      longitude: 139.6503
    },
    # Australia
    australia: {
      country_name: "Australia",
      country_code: "AU",
      region_name: "NSW",
      city_name: "Sydney",
      postal_code: "2000",
      latitude: -33.8688,
      longitude: 151.2093
    },
    # Italy
    italy: {
      country_name: "Italy",
      country_code: "IT",
      region_name: "RM",
      city_name: "Rome",
      postal_code: "00100",
      latitude: 41.9028,
      longitude: 12.4964
    },
    # Libya (blocked country for compliance testing)
    libya: {
      country_name: "Libya",
      country_code: "LY",
      region_name: nil,
      city_name: "Tripoli",
      postal_code: nil,
      latitude: 32.8872,
      longitude: 13.1913
    },
    # Belgium (for French-specific tests)
    belgium: {
      country_name: "Belgium",
      country_code: "BE",
      region_name: "BRU",
      city_name: "Brussels",
      postal_code: "1000",
      latitude: 50.8503,
      longitude: 4.3517
    },
    # India
    india: {
      country_name: "India",
      country_code: "IN",
      region_name: "DL",
      city_name: "New Delhi",
      postal_code: "110001",
      latitude: 28.6139,
      longitude: 77.2090
    },
    # South Korea
    south_korea: {
      country_name: "South Korea",
      country_code: "KR",
      region_name: "11",
      city_name: "Seoul",
      postal_code: "04524",
      latitude: 37.5665,
      longitude: 126.9780
    },
    # Taiwan
    taiwan: {
      country_name: "Taiwan",
      country_code: "TW",
      region_name: "TPE",
      city_name: "Taipei",
      postal_code: "100",
      latitude: 25.0330,
      longitude: 121.5654
    },
    # Latvia
    latvia: {
      country_name: "Latvia",
      country_code: "LV",
      region_name: "RIX",
      city_name: "Riga",
      postal_code: "LV-1050",
      latitude: 56.9496,
      longitude: 24.1052
    },
    # Czechia
    czechia: {
      country_name: "Czechia",
      country_code: "CZ",
      region_name: "PR",
      city_name: "Prague",
      postal_code: "110 00",
      latitude: 50.0755,
      longitude: 14.4378
    },
    # Norway
    norway: {
      country_name: "Norway",
      country_code: "NO",
      region_name: "03",
      city_name: "Oslo",
      postal_code: "0010",
      latitude: 59.9139,
      longitude: 10.7522
    },
    # Iceland
    iceland: {
      country_name: "Iceland",
      country_code: "IS",
      region_name: "1",
      city_name: "Reykjavik",
      postal_code: "101",
      latitude: 64.1466,
      longitude: -21.9426
    },
    # New Zealand
    new_zealand: {
      country_name: "New Zealand",
      country_code: "NZ",
      region_name: "AUK",
      city_name: "Auckland",
      postal_code: "1010",
      latitude: -36.8485,
      longitude: 174.7633
    },
    # South Africa
    south_africa: {
      country_name: "South Africa",
      country_code: "ZA",
      region_name: "GP",
      city_name: "Johannesburg",
      postal_code: "2001",
      latitude: -26.2041,
      longitude: 28.0473
    },
    # Switzerland
    switzerland: {
      country_name: "Switzerland", 
      country_code: "CH",
      region_name: "ZH",
      city_name: "Zurich",
      postal_code: "8001",
      latitude: 47.3769,
      longitude: 8.5417
    },
    # UAE
    uae: {
      country_name: "United Arab Emirates",
      country_code: "AE",
      region_name: "DU",
      city_name: "Dubai",
      postal_code: nil,
      latitude: 25.2048,
      longitude: 55.2708
    },
    # Singapore
    singapore: {
      country_name: "Singapore",
      country_code: "SG",
      region_name: nil,
      city_name: "Singapore",
      postal_code: "018956",
      latitude: 1.3521,
      longitude: 103.8198
    }
  }.freeze

  # Common test IP addresses mapped to their default locations
  IP_ADDRESS_DEFAULTS = {
    "104.193.168.19" => :us,        # San Francisco, US
    "76.66.210.142" => :canada,      # Canadian IP
    "2.47.255.255" => :italy,        # Italian IP
    "41.208.70.70" => :libya,        # Libyan IP (blocked)
    "8.8.8.8" => :us,                # Google DNS (US)
    "2001:861:5bc0:cb60:500d:3535:e6a7:62a0" => :france, # French IPv6
    "127.0.0.1" => nil,              # Localhost (no location)
    "localhost" => nil,              # Localhost (no location)
    "192.168.0.1" => nil,            # Private IP (no location)
    "12.12.128.128" => :us,          # Generic US IP
    "72.229.28.185" => :us,          # US IP for shipping tests
    "109.110.31.255" => :latvia,     # Latvia IP for PPP tests
    "103.48.196.103" => :india,      # India IP for tax tests
    "1.208.105.19" => :south_korea,  # South Korea IP
    "1.174.208.0" => :taiwan,        # Taiwan IP
    "199.21.86.138" => :us           # US IP for zip code tests
  }.freeze

  # Stub GeoIp.lookup to return a Result object with the given attributes
  # 
  # @param ip [String] The IP address to stub
  # @param attrs [Hash, Symbol, nil] Attributes for the GeoIP result.
  #   Can be:
  #   - A Symbol key from DEFAULT_GEOIP_DATA (e.g., :us, :canada, :france)
  #   - A Hash with custom attributes (will be merged with US defaults)
  #   - nil to return nil (no GeoIP data available)
  # 
  # @example Using predefined country data
  #   stub_geoip("192.168.1.1", :canada)
  #   
  # @example Using custom attributes
  #   stub_geoip("10.0.0.1", country_name: "Brazil", country_code: "BR")
  #   
  # @example Stubbing to return nil
  #   stub_geoip("127.0.0.1", nil)
  def stub_geoip(ip, attrs = nil)
    # If attrs is nil explicitly, return nil
    if attrs.nil?
      allow(GeoIp).to receive(:lookup).with(ip).and_return(nil)
      return
    end

    # If attrs is a symbol, use the predefined data
    if attrs.is_a?(Symbol)
      attrs = DEFAULT_GEOIP_DATA[attrs] || DEFAULT_GEOIP_DATA[:us]
    end

    # If attrs is a hash, merge with US defaults for any missing values
    if attrs.is_a?(Hash)
      attrs = DEFAULT_GEOIP_DATA[:us].merge(attrs)
    end

    # Create a Result object
    result = GeoIp::Result.new(
      country_name: attrs[:country_name],
      country_code: attrs[:country_code],
      region_name: attrs[:region_name],
      city_name: attrs[:city_name],
      postal_code: attrs[:postal_code],
      latitude: attrs[:latitude],
      longitude: attrs[:longitude]
    )

    allow(GeoIp).to receive(:lookup).with(ip).and_return(result)
  end

  # Stub GeoIp.lookup with default data based on common test IPs
  # This method automatically stubs known test IPs with their expected locations
  # 
  # @example
  #   stub_default_geoip_lookups
  #   # Now GeoIp.lookup("104.193.168.19") returns US data
  #   # And GeoIp.lookup("76.66.210.142") returns Canada data
  def stub_default_geoip_lookups
    IP_ADDRESS_DEFAULTS.each do |ip, location_key|
      if location_key.nil?
        stub_geoip(ip, nil)
      else
        stub_geoip(ip, location_key)
      end
    end
  end

  # Stub GeoIp.lookup to always return data for a specific country
  # Useful for testing country-specific logic
  # 
  # @param country_key [Symbol] The country key from DEFAULT_GEOIP_DATA
  # 
  # @example
  #   stub_geoip_for_any_ip(:canada)
  #   # Now any IP address will return Canadian data
  def stub_geoip_for_any_ip(country_key)
    attrs = DEFAULT_GEOIP_DATA[country_key] || DEFAULT_GEOIP_DATA[:us]
    result = GeoIp::Result.new(
      country_name: attrs[:country_name],
      country_code: attrs[:country_code],
      region_name: attrs[:region_name],
      city_name: attrs[:city_name],
      postal_code: attrs[:postal_code],
      latitude: attrs[:latitude],
      longitude: attrs[:longitude]
    )

    allow(GeoIp).to receive(:lookup).and_return(result)
  end

  # Stub GeoIp.lookup to always return nil (no location data)
  # Useful for testing behavior when GeoIP data is unavailable
  # 
  # @example
  #   stub_geoip_unavailable
  #   # Now any IP address lookup will return nil
  def stub_geoip_unavailable
    allow(GeoIp).to receive(:lookup).and_return(nil)
  end

  # Helper to create a double that mimics GeoIp::Result
  # Useful when you need more control over the mock object
  # 
  # @param attrs [Hash] Attributes for the result
  # @return [Double] A test double that responds like GeoIp::Result
  # 
  # @example
  #   result = geoip_result_double(country_code: "MX", country_name: "Mexico")
  #   allow(GeoIp).to receive(:lookup).and_return(result)
  def geoip_result_double(attrs = {})
    attrs = DEFAULT_GEOIP_DATA[:us].merge(attrs)
    double(
      "GeoIp::Result",
      country_name: attrs[:country_name],
      country_code: attrs[:country_code],
      region_name: attrs[:region_name],
      city_name: attrs[:city_name],
      postal_code: attrs[:postal_code],
      latitude: attrs[:latitude],
      longitude: attrs[:longitude]
    )
  end

  # Helper for request specs that need to stub both GeoIP and ActionDispatch
  # This is commonly needed for Capybara/feature specs
  # 
  # @param ip [String] The IP address to stub
  # @param country_code [String] The two-letter country code
  # @param country_name [String] Optional country name
  # 
  # @example
  #   stub_request_ip("2.47.255.255", "IT", "Italy")
  def stub_request_ip(ip, country_code, country_name = nil)
    # Stub GeoIP lookup
    if country_name
      stub_geoip(ip, country_code: country_code, country_name: country_name)
    else
      stub_geoip(ip, country_code: country_code)
    end
    
    # Also stub ActionDispatch for Capybara compatibility
    allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return(ip)
  end
end

# Configure RSpec to include the helper module
RSpec.configure do |config|
  config.include GeoipHelpers
  
  # Optionally, automatically stub default GeoIP lookups for all tests
  # Uncomment the following lines if you want this behavior:
  # config.before(:each) do
  #   stub_default_geoip_lookups
  # end
end