# Processes an already-verified, already-deduped webhook event asynchronously
# — the controller's only job is to authenticate the request and record the
# event id fast; actually applying the status transition (which touches
# Ride's state machine) happens here, off the request/response cycle, the
# same way a real vendor webhook handler would enqueue work rather than do
# it inline.
class RideStatusWebhookJob < ApplicationJob
  queue_as :default

  def perform(webhook_event_id)
    event = WebhookEvent.find(webhook_event_id)
    payload = event.payload

    ride = Ride.find_by(id: payload["ride_id"])
    if ride.nil?
      Rails.logger.warn("RideStatusWebhookJob: no ride ##{payload['ride_id']} for event #{event.event_id}")
      return event.update!(processed_at: Time.current)
    end

    actor = TransportProvider.find_by(id: payload["transport_provider_id"])
    apply_status!(ride, payload["status"], actor)

    event.update!(processed_at: Time.current)
  end

  private

  # A vendor webhook can arrive out of order or duplicate a transition we've
  # already made through some other path (e.g. a coordinator cancelling in
  # the UI right as the vendor's "trip started" event lands). If the guard
  # says the transition doesn't apply, we log and drop it rather than raise
  # — the event is still marked processed either way.
  def apply_status!(ride, status, actor)
    case status
    when "in_progress"
      ride.start!(actor: actor) if ride.can_start?
    when "completed"
      ride.complete!(actor: actor) if ride.can_complete?
    when "cancelled"
      ride.cancel!(actor: actor) if ride.can_cancel?
    else
      Rails.logger.warn("RideStatusWebhookJob: unrecognized status #{status.inspect} for ride ##{ride.id}")
    end
  end
end
