class CreateRideStatusEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :ride_status_events do |t|
      t.references :ride, null: false, foreign_key: true

      # Polymorphic rather than a hard FK to one actor table, because a
      # transition can be caused by a Coordinator, a TransportProvider, or
      # nothing at all (nil actor = the system/a vendor webhook).
      t.references :actor, polymorphic: true, null: true

      t.integer :from_status
      t.integer :to_status, null: false
      t.datetime :occurred_at, null: false

      # Free-form context, e.g. the raw webhook payload that drove this
      # transition. Keeps the audit trail self-contained without a second table.
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ride_status_events, :occurred_at
  end
end
