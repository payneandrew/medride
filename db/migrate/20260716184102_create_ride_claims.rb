class CreateRideClaims < ActiveRecord::Migration[8.0]
  def change
    create_table :ride_claims do |t|
      t.references :ride, null: false, foreign_key: true
      t.references :transport_provider, null: false, foreign_key: true
      t.datetime :claimed_at, null: false
      t.datetime :released_at

      t.timestamps
    end

    # The concurrency guard: at most one *active* (released_at IS NULL) claim
    # per ride. Two providers racing to claim the same ride both pass the
    # Rails-level "is this ride still requested?" check, but only one INSERT
    # can win here — the loser gets a Postgres unique_violation, which the
    # model layer turns into a friendly "already claimed" result. This is
    # enforced at the database level because a Ride.status check in Ruby is
    # not atomic across two concurrent requests.
    add_index :ride_claims, :ride_id, unique: true,
              where: "released_at IS NULL",
              name: "index_ride_claims_on_active_claim"
  end
end
