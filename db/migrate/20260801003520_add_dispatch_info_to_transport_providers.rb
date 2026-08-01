class AddDispatchInfoToTransportProviders < ActiveRecord::Migration[8.0]
  def change
    # base_lat/lng: this provider's dispatch base, used by
    # ProviderRanking::DistanceScore to estimate how far they are from a
    # given pickup. Nullable — Uber Health has no fixed base (see
    # db/seeds.rb), and DistanceScore falls back to a neutral score rather
    # than requiring one.
    add_column :transport_providers, :base_lat, :decimal, precision: 9, scale: 6
    add_column :transport_providers, :base_lng, :decimal, precision: 9, scale: 6
    add_column :transport_providers, :base_fare_cents, :integer, null: false, default: 500
    add_column :transport_providers, :rate_per_mile_cents, :integer, null: false, default: 200
  end
end
