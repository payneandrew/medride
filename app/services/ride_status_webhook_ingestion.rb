# Shared by WebhooksController (our own vendor webhook shape) and
# UberHealthWebhooksController (Uber's shape, translated to ours first) —
# both boil down to the same two properties: idempotent on event_id,
# processed asynchronously. Pulling this out once a second webhook source
# existed avoids two independently-maintained copies of the
# save-then-enqueue-then-handle-the-race dance drifting apart.
class RideStatusWebhookIngestion
  Result = Struct.new(:accepted, :already_processed, keyword_init: true)

  def self.call(event_id:, payload:)
    event = WebhookEvent.new(event_id: event_id, payload: payload)

    if event.save
      RideStatusWebhookJob.perform_later(event.id)
      Result.new(accepted: true, already_processed: false)
    else
      Result.new(accepted: false, already_processed: true)
    end
  end
end
