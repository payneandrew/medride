class CreateCareOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :care_organizations do |t|
      t.string :name, null: false
      # hospital vs health_plan: no behavioral difference yet, but keeps the
      # door open for org-type-specific booking rules later.
      t.integer :org_type, null: false, default: 0

      t.timestamps
    end
  end
end
