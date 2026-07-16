class AddExternalRideIdToRideClaims < ActiveRecord::Migration[8.0]
  def change
    # Set when a claim was created by dispatching to an external API
    # (Uber Health, Lyft Concierge) rather than a provider claiming from the
    # marketplace pool — their ride id, not ours, since their webhooks only
    # know their own id and we have to map it back to a Ride ourselves.
    add_column :ride_claims, :external_ride_id, :string
    add_index :ride_claims, :external_ride_id, unique: true, where: "external_ride_id IS NOT NULL"
  end
end
