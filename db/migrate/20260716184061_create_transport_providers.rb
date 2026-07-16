class CreateTransportProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :transport_providers do |t|
      t.string :name, null: false
      t.string :phone, null: false
      # Simple model of coverage: the zip codes this provider will pick up
      # from. A real marketplace would use geo polygons/drive-time, but a zip
      # list is enough to demonstrate the matching logic.
      t.string :service_area, array: true, null: false, default: []

      t.timestamps
    end

    add_index :transport_providers, :service_area, using: "gin"
  end
end
