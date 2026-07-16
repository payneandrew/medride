# Same two jobs as WebhooksController (authenticate, dedupe) plus one more
# this vendor requires: translating their ride id and status vocabulary
# into ours before handing off to the same ingestion/processing pipeline.
# Uber's webhook only knows *their* ride id — RideClaim#external_ride_id
# (set when we dispatched via UberHealth::DispatchRide) is what maps it
# back to one of our Rides.
class UberHealthWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def ride_status
    raw_body = request.raw_post

    unless UberHealth::WebhookSigner.valid?(raw_body, request.headers["X-Uber-Signature"])
      return render json: { error: "invalid signature" }, status: :unauthorized
    end

    payload = JSON.parse(raw_body)
    event_id = payload["event_id"].to_s
    return render json: { error: "missing event_id" }, status: :unprocessable_entity if event_id.blank?

    claim = RideClaim.find_by(external_ride_id: payload["ride_id"])
    unless claim
      return render json: { error: "unknown external ride_id #{payload['ride_id']}" }, status: :unprocessable_entity
    end

    canonical_payload = {
      "event_id" => event_id,
      "ride_id" => claim.ride_id,
      "status" => UberHealth::StatusTranslator.call(payload["status"]) || payload["status"],
      "transport_provider_id" => claim.transport_provider_id,
      "occurred_at" => payload["timestamp"]
    }

    result = RideStatusWebhookIngestion.call(event_id: event_id, payload: canonical_payload)

    if result.accepted
      render json: { status: "accepted" }, status: :accepted
    else
      render json: { status: "already_processed" }, status: :ok
    end
  rescue JSON::ParserError
    render json: { error: "invalid JSON" }, status: :bad_request
  end
end
