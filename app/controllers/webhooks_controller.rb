# Simulates receiving status-update webhooks from a transport vendor's
# system (the way a rideshare API pushes "driver arrived"/"trip
# completed"-style events). Two properties matter for any webhook receiver:
# authenticity (HMAC signature over the raw body) and idempotency (a
# retried delivery must not double-apply). Actually acting on the event
# happens in a background job — see RideStatusWebhookJob.
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def ride_status
    raw_body = request.raw_post

    unless RideStatusWebhookSigner.valid?(raw_body, request.headers["X-Medride-Signature"])
      return render json: { error: "invalid signature" }, status: :unauthorized
    end

    payload = JSON.parse(raw_body)
    event_id = payload["event_id"].to_s

    if event_id.blank?
      return render json: { error: "missing event_id" }, status: :unprocessable_entity
    end

    result = RideStatusWebhookIngestion.call(event_id: event_id, payload: payload)

    if result.accepted
      render json: { status: "accepted" }, status: :accepted
    else
      # Already seen this event_id. Responding 200 here (not an error) is
      # the point — vendors retry on anything but 2xx, so treating a
      # duplicate as success is what makes retries safe.
      render json: { status: "already_processed" }, status: :ok
    end
  rescue JSON::ParserError
    render json: { error: "invalid JSON" }, status: :bad_request
  end
end
