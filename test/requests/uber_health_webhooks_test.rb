require "test_helper"

class UberHealthWebhooksTest < ActionDispatch::IntegrationTest
  test "translates Uber's status vocabulary and enqueues processing" do
    payload = build_payload(event_id: "uevt-1", status: "trip_started")

    assert_enqueued_with(job: RideStatusWebhookJob) do
      post webhooks_uber_health_ride_status_path, params: payload, headers: signed_headers(payload)
    end

    assert_response :accepted
  end

  test "rejects an invalid signature" do
    payload = build_payload(event_id: "uevt-2", status: "trip_started")

    post webhooks_uber_health_ride_status_path, params: payload,
      headers: { "Content-Type" => "application/json", "X-Uber-Signature" => "sha256=bogus" }

    assert_response :unauthorized
  end

  test "rejects an unknown external ride id" do
    payload = { event_id: "uevt-3", ride_id: "does-not-exist", status: "trip_started", timestamp: Time.current.iso8601 }.to_json

    post webhooks_uber_health_ride_status_path, params: payload, headers: signed_headers(payload)

    assert_response :unprocessable_entity
  end

  test "is idempotent on event_id" do
    payload = build_payload(event_id: "uevt-4", status: "trip_started")
    headers = signed_headers(payload)

    assert_difference "WebhookEvent.count", 1 do
      post webhooks_uber_health_ride_status_path, params: payload, headers: headers
    end
    assert_response :accepted

    assert_no_difference "WebhookEvent.count" do
      post webhooks_uber_health_ride_status_path, params: payload, headers: headers
    end
    assert_response :ok
  end

  test "an unrecognized status (e.g. driver arriving) is accepted but doesn't transition the ride" do
    payload = build_payload(event_id: "uevt-5", status: "arriving")

    perform_enqueued_jobs do
      post webhooks_uber_health_ride_status_path, params: payload, headers: signed_headers(payload)
    end

    assert_response :accepted
    assert_equal "claimed", rides(:uber_dispatched_ride).reload.status
  end

  private

  def build_payload(event_id:, status:)
    {
      event_id: event_id,
      ride_id: ride_claims(:uber_active_claim).external_ride_id,
      status: status,
      timestamp: Time.current.iso8601
    }.to_json
  end

  def signed_headers(payload)
    { "Content-Type" => "application/json", "X-Uber-Signature" => UberHealth::WebhookSigner.sign(payload) }
  end
end
