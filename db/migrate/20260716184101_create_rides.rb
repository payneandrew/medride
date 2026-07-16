class CreateRides < ActiveRecord::Migration[8.0]
  def change
    create_table :rides do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :coordinator, null: false, foreign_key: true

      t.string :pickup_address_line1, null: false
      t.string :pickup_city, null: false
      t.string :pickup_state, null: false
      t.string :pickup_zip, null: false

      t.string :dropoff_address_line1, null: false
      t.string :dropoff_city, null: false
      t.string :dropoff_state, null: false
      t.string :dropoff_zip, null: false

      t.datetime :scheduled_at, null: false
      t.integer :level_of_service, null: false
      t.integer :status, null: false, default: 0

      # Set when EligibilityCheck says this level_of_service requires prior
      # authorization. The ride still books (status stays "requested"), it's
      # just flagged for a human to clear before a provider should claim it.
      t.boolean :needs_authorization, null: false, default: false

      t.timestamps
    end

    add_index :rides, :status
    add_index :rides, :pickup_zip
  end
end
