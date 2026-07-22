require "net/http"

module SmartOnFhir
  # Discovers a FHIR server's OAuth2 endpoints via the SMART "well-known"
  # configuration document (SMART App Launch spec, "Discovery"). This is
  # what lets a launch target *any* iss instead of a single hardcoded
  # authorization server — Fhir::Client, by contrast, always talks to one
  # fixed, unauthenticated FHIR server (BASE_URL).
  class Configuration
    class Error < StandardError; end

    Result = Struct.new(:authorization_endpoint, :token_endpoint, keyword_init: true)

    def self.discover(iss)
      new(iss).discover
    end

    def initialize(iss)
      @iss = iss.to_s.chomp("/")
    end

    def discover
      uri = URI.parse("#{@iss}/.well-known/smart-configuration")
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "smart-configuration discovery failed for #{@iss} (#{response.code})"
      end

      body = JSON.parse(response.body)
      Result.new(
        authorization_endpoint: body.fetch("authorization_endpoint"),
        token_endpoint: body.fetch("token_endpoint")
      )
    rescue JSON::ParserError, KeyError => e
      raise Error, "malformed smart-configuration document from #{@iss}: #{e.message}"
    end
  end
end
