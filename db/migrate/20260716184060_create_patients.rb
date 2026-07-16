class CreatePatients < ActiveRecord::Migration[8.0]
  def change
    create_table :patients do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone, null: false

      t.string :home_address_line1, null: false
      t.string :home_address_line2
      t.string :home_city, null: false
      t.string :home_state, null: false
      t.string :home_zip, null: false

      # Identifier from the source-of-truth EHR (FHIR Patient.id on the HAPI
      # test server). Nullable: a coordinator can hand-enter a patient who has
      # no EHR record yet. In a real system this would be a proper
      # Patient.identifier (system + value), since a patient can have many
      # identifiers (MRN per facility, SSN, etc.) — a single string column is
      # a simplification for this project.
      t.string :fhir_id
      t.string :insurance_member_id

      t.references :benefit_plan, foreign_key: true

      # Drives the right-sizing check: the most expensive level_of_service
      # this patient can legitimately require, independent of what gets booked.
      t.integer :mobility_needs, null: false, default: 0

      t.timestamps
    end

    add_index :patients, :fhir_id, unique: true
  end
end
