class CreateWebhookEvents < ActiveRecord::Migration[8.0]
  def change
    # One row per inbound webhook event_id: the unique index is what makes
    # the endpoint idempotent — a retried delivery with the same event_id
    # hits the uniqueness violation and is treated as a no-op instead of
    # being processed twice.
    create_table :webhook_events do |t|
      t.string :event_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :webhook_events, :event_id, unique: true
  end
end
