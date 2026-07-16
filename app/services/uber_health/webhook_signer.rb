module UberHealth
  # Deliberately a separate secret/scheme from RideStatusWebhookSigner, not
  # a shared constant — this is a genuinely different integration boundary
  # (a different vendor with its own signing convention), and coupling the
  # two would make rotating one secret risk breaking the other integration.
  class WebhookSigner
    def self.sign(body)
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
    end

    def self.valid?(body, signature_header)
      return false if signature_header.blank?

      ActiveSupport::SecurityUtils.secure_compare(sign(body), signature_header)
    rescue ArgumentError
      false
    end

    def self.secret
      Rails.application.credentials.dig(:uber_health_webhook_secret) ||
        ENV.fetch("UBER_HEALTH_WEBHOOK_SECRET", "development-uber-health-webhook-secret")
    end
  end
end
