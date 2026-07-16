require "test_helper"

class WebhooksTest < ActionDispatch::IntegrationTest
  test "accepts a validly signed event and enqueues it for processing" do
    payload = build_payload(event_id: "evt-1")

    assert_enqueued_with(job: RideStatusWebhookJob) do
      post webhooks_ride_status_path, params: payload, headers: signed_headers(payload)
    end

    assert_response :accepted
  end

  test "rejects a request with an invalid signature" do
    payload = build_payload(event_id: "evt-2")

    post webhooks_ride_status_path, params: payload,
      headers: { "Content-Type" => "application/json", "X-Medride-Signature" => "sha256=bogus" }

    assert_response :unauthorized
  end

  test "rejects a request with no signature header at all" do
    payload = build_payload(event_id: "evt-3")

    post webhooks_ride_status_path, params: payload, headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  test "is idempotent on event_id: a repeated delivery is a no-op, not a double transition" do
    payload = build_payload(event_id: "evt-4")
    headers = signed_headers(payload)

    assert_difference "WebhookEvent.count", 1 do
      post webhooks_ride_status_path, params: payload, headers: headers
    end
    assert_response :accepted

    assert_no_difference "WebhookEvent.count" do
      post webhooks_ride_status_path, params: payload, headers: headers
    end
    assert_response :ok
  end

  private

  def build_payload(event_id:)
    {
      event_id: event_id,
      ride_id: rides(:claimed_ride).id,
      status: "in_progress",
      transport_provider_id: transport_providers(:acme).id
    }.to_json
  end

  def signed_headers(payload)
    { "Content-Type" => "application/json", "X-Medride-Signature" => RideStatusWebhookSigner.sign(payload) }
  end
end
