# Shared between WebhooksController (verifying inbound signatures) and the
# webhooks:fire_ride_status rake task (signing outbound fake events), so
# there's exactly one place that knows the secret and the signing scheme.
class RideStatusWebhookSigner
  def self.sign(body)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
  end

  def self.valid?(body, signature_header)
    return false if signature_header.blank?

    ActiveSupport::SecurityUtils.secure_compare(sign(body), signature_header)
  rescue ArgumentError
    # secure_compare raises on a length mismatch rather than returning
    # false — an attacker- (or typo-) controlled header of the wrong length
    # should just fail verification, not blow up the request.
    false
  end

  def self.secret
    Rails.application.credentials.dig(:ride_status_webhook_secret) ||
      ENV.fetch("RIDE_STATUS_WEBHOOK_SECRET", "development-webhook-secret")
  end
end
