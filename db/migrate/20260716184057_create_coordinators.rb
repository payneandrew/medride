class CreateCoordinators < ActiveRecord::Migration[8.0]
  def change
    create_table :coordinators do |t|
      t.references :care_organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false

      t.timestamps
    end

    add_index :coordinators, :email, unique: true
  end
end
