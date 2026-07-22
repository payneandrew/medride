require "securerandom"
require "digest"
require "base64"

module SmartOnFhir
  # Builds the redirect to the authorization server for either launch type
  # (SMART App Launch spec, "App launch: EHR launch" / "App launch:
  # Standalone launch"), including PKCE (RFC 7636) — required by SMART v2
  # even for confidential-looking flows, since the code is exposed in a
  # browser redirect.
  class AuthorizationRequest
    Result = Struct.new(:url, :state, :code_verifier, keyword_init: true)

    def self.build(iss:, authorization_endpoint:, client_id:, redirect_uri:, launch: nil)
      new(iss: iss, authorization_endpoint: authorization_endpoint, client_id: client_id,
          redirect_uri: redirect_uri, launch: launch).build
    end

    def initialize(iss:, authorization_endpoint:, client_id:, redirect_uri:, launch: nil)
      @iss = iss
      @authorization_endpoint = authorization_endpoint
      @client_id = client_id
      @redirect_uri = redirect_uri
      @launch = launch
    end

    def build
      state = SecureRandom.hex(16)
      code_verifier = SecureRandom.urlsafe_base64(48)
      code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)

      params = {
        response_type: "code",
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        scope: scope,
        state: state,
        aud: @iss,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      }
      params[:launch] = @launch if @launch.present?

      uri = URI.parse(@authorization_endpoint)
      uri.query = URI.encode_www_form(params)

      Result.new(url: uri.to_s, state: state, code_verifier: code_verifier)
    end

    private

    # EHR launch (launch param present) requests the "launch" scope, since
    # the launch context (which patient) was already established by the EHR
    # before it redirected here. Standalone launch has no such context yet,
    # so it requests "launch/patient" instead — that's what tells the
    # authorization server to prompt the user to pick a patient during the
    # authorize step, and is what puts a `patient` id in the token response
    # at all.
    def scope
      launch_scope = @launch.present? ? "launch" : "launch/patient"
      "#{launch_scope} openid fhirUser patient/Patient.read patient/Appointment.read"
    end
  end
end
