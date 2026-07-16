class CreateTransportProviderCapabilities < ActiveRecord::Migration[8.0]
  def change
    # Join table (provider <-> capability) rather than an array/string column
    # on transport_providers, so each capability is a queryable, indexable
    # row and the set can grow (e.g. adding a "non_ambulatory_bariatric" tier)
    # without a migration touching the providers table itself.
    create_table :transport_provider_capabilities do |t|
      t.references :transport_provider, null: false, foreign_key: true
      t.integer :capability, null: false

      t.timestamps
    end

    add_index :transport_provider_capabilities, [ :transport_provider_id, :capability ],
              unique: true, name: "index_capabilities_on_provider_and_capability"
  end
end
