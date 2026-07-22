require "oauth2"

module SmartOnFhir
  # Exchanges an authorization code (+ PKCE verifier) for an access token at
  # the SMART authorization server's token endpoint. The `patient` field in
  # the token response is the SMART launch context — with a real EHR
  # launch that's the patient the clinician already had open; with a
  # standalone launch it's whichever patient the user picked on the
  # authorization server's consent screen (see AuthorizationRequest's
  # "launch/patient" scope).
  class TokenExchange
    class Error < StandardError; end

    Result = Struct.new(:access_token, :patient_id, :expires_in, keyword_init: true)

    def self.call(token_endpoint:, code:, code_verifier:, redirect_uri:, client_id:)
      new(token_endpoint: token_endpoint, code: code, code_verifier: code_verifier,
          redirect_uri: redirect_uri, client_id: client_id).call
    end

    def initialize(token_endpoint:, code:, code_verifier:, redirect_uri:, client_id:)
      @token_endpoint = token_endpoint
      @code = code
      @code_verifier = code_verifier
      @redirect_uri = redirect_uri
      @client_id = client_id
    end

    def call
      access_token = oauth2_client.auth_code.get_token(
        @code,
        redirect_uri: @redirect_uri,
        code_verifier: @code_verifier
      )

      Result.new(
        access_token: access_token.token,
        patient_id: access_token["patient"],
        expires_in: access_token.expires_in
      )
    rescue OAuth2::Error => e
      raise Error, "SMART token exchange failed: #{e.message}"
    end

    private

    # Public SMART sandboxes (and most public/PKCE clients) don't require a
    # client_secret; auth_scheme: :request_body puts client_id/code/verifier
    # in the POST body rather than an Authorization: Basic header, which is
    # what a public client without a secret needs.
    def oauth2_client
      OAuth2::Client.new(
        @client_id, nil,
        site: @token_endpoint,
        token_url: @token_endpoint,
        auth_scheme: :request_body
      )
    end
  end
end
