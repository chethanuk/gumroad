#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to validate VCR cassettes and check for exposed credentials
# Usage: ruby script/validate_vcr_cassettes.rb

require 'yaml'
require 'pathname'
require 'colorize'

class VcrCassetteValidator
  CASSETTE_DIR = File.expand_path('../spec/support/fixtures/vcr_cassettes', __dir__)
  
  # Patterns that might indicate real credentials
  SENSITIVE_PATTERNS = {
    # API Keys (not the dummy_ or test_ prefixed ones)
    api_keys: /(?<!dummy_|test_|fake_)([A-Za-z0-9]{20,}|sk_[a-zA-Z0-9]{24,}|pk_[a-zA-Z0-9]{24,})/,
    
    # Email addresses that aren't test/example domains
    emails: /[a-zA-Z0-9._%+-]+@(?!example\.com|test\.com|paypal\.test|gumroad\.test)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
    
    # Bearer tokens
    bearer_tokens: /Bearer\s+[A-Za-z0-9\-._~\+\/]+=*/,
    
    # AWS credentials
    aws_keys: /AKIA[0-9A-Z]{16}/,
    
    # Private keys
    private_keys: /-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----/,
    
    # Passwords in URLs or headers
    passwords: /(password|passwd|pwd)[:=]["'](?!dummy|test|fake)[^"']+["']/i,
    
    # Credit card numbers (basic pattern)
    credit_cards: /\b(?:\d{4}[\s\-]?){3}\d{4}\b/
  }
  
  # Known safe patterns that should be ignored
  SAFE_PATTERNS = [
    /dummy_/,
    /test_/,
    /fake_/,
    /<[A-Z_]+>/, # VCR filter placeholders like <API_KEY>
    /\{\{.+\}\}/, # Template variables
    /example\.com/,
    /localhost/,
    /127\.0\.0\.1/,
    /0\.0\.0\.0/
  ]
  
  def initialize
    @errors = []
    @warnings = []
    @cassettes_checked = 0
  end
  
  def validate!
    puts "🔍 Validating VCR cassettes in: #{CASSETTE_DIR}".blue
    puts "-" * 60
    
    unless Dir.exist?(CASSETTE_DIR)
      puts "❌ Cassette directory not found: #{CASSETTE_DIR}".red
      return false
    end
    
    cassette_files = Dir.glob(File.join(CASSETTE_DIR, '**/*.yml'))
    
    if cassette_files.empty?
      puts "⚠️  No VCR cassettes found".yellow
      return true
    end
    
    puts "Found #{cassette_files.length} cassette files to validate".cyan
    puts
    
    cassette_files.each do |file|
      validate_cassette(file)
    end
    
    print_summary
    @errors.empty?
  end
  
  private
  
  def validate_cassette(file)
    @cassettes_checked += 1
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(CASSETTE_DIR))
    
    begin
      content = File.read(file)
      cassette = YAML.load(content)
      
      # Check if cassette is properly formatted
      unless cassette.is_a?(Hash) && cassette['http_interactions']
        @warnings << "#{relative_path}: Invalid cassette format"
        return
      end
      
      # Check for sensitive patterns in the raw content
      check_sensitive_content(relative_path, content)
      
      # Check if cassette has dummy credential markers
      if content.include?('dummy_') || content.include?('fake_')
        @warnings << "#{relative_path}: Contains dummy credential markers - may need re-recording"
      end
      
      print "."
    rescue => e
      @errors << "#{relative_path}: Failed to parse - #{e.message}"
      print "E".red
    end
  end
  
  def check_sensitive_content(file_path, content)
    lines = content.split("\n")
    
    lines.each_with_index do |line, index|
      next if safe_line?(line)
      
      SENSITIVE_PATTERNS.each do |pattern_type, pattern|
        if line.match?(pattern)
          line_num = index + 1
          @warnings << "#{file_path}:#{line_num} - Potential #{pattern_type.to_s.tr('_', ' ')}: #{line[0..100]}..."
        end
      end
    end
  end
  
  def safe_line?(line)
    SAFE_PATTERNS.any? { |pattern| line.match?(pattern) }
  end
  
  def print_summary
    puts "\n"
    puts "=" * 60
    puts "📊 Validation Summary".bold
    puts "=" * 60
    
    puts "✅ Cassettes checked: #{@cassettes_checked}".green
    
    if @errors.any?
      puts "\n❌ Errors (#{@errors.length}):".red.bold
      @errors.each { |error| puts "  • #{error}".red }
    end
    
    if @warnings.any?
      puts "\n⚠️  Warnings (#{@warnings.length}):".yellow.bold
      @warnings.take(10).each { |warning| puts "  • #{warning}".yellow }
      if @warnings.length > 10
        puts "  ... and #{@warnings.length - 10} more warnings".yellow
      end
    end
    
    if @errors.empty? && @warnings.empty?
      puts "\n✨ All cassettes look good!".green.bold
    elsif @errors.empty?
      puts "\n⚠️  Validation passed with warnings - review them carefully".yellow.bold
    else
      puts "\n❌ Validation failed - fix errors before proceeding".red.bold
    end
    
    puts "=" * 60
  end
end

# Add colorize String extensions if not available
unless String.method_defined?(:colorize)
  class String
    def colorize(color_code)
      "\e[#{color_code}m#{self}\e[0m"
    end
    
    def red; colorize(31); end
    def green; colorize(32); end
    def yellow; colorize(33); end
    def blue; colorize(34); end
    def cyan; colorize(36); end
    def bold; colorize(1); end
  end
end

# Run the validator
if __FILE__ == $0
  validator = VcrCassetteValidator.new
  exit(validator.validate! ? 0 : 1)
end