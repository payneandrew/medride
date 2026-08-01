class AddLocationToRides < ActiveRecord::Migration[8.0]
  def change
    # Nullable and only populated when the address was picked via the Places
    # Autocomplete widget (see address_autocomplete_controller.js) — a
    # hand-typed or patient-home-address-prefilled pickup/dropoff has no
    # coordinates, and ProviderRanking degrades to neutral defaults when
    # they're missing rather than requiring them.
    add_column :rides, :pickup_lat, :decimal, precision: 9, scale: 6
    add_column :rides, :pickup_lng, :decimal, precision: 9, scale: 6
    add_column :rides, :dropoff_lat, :decimal, precision: 9, scale: 6
    add_column :rides, :dropoff_lng, :decimal, precision: 9, scale: 6
  end
end
