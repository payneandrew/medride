class CreateBenefitCoverageRules < ActiveRecord::Migration[8.0]
  def change
    # One row per (plan, level_of_service): stands in for the "insurance.item"
    # array on a real FHIR CoverageEligibilityResponse, where each item names
    # a benefit category and its limits. Flattened into a table so
    # EligibilityCheck can look rows up instead of parsing FHIR at request time.
    create_table :benefit_coverage_rules do |t|
      t.references :benefit_plan, null: false, foreign_key: true
      t.integer :level_of_service, null: false
      t.boolean :covered, null: false, default: true
      t.integer :trip_limit # nil means unlimited
      t.boolean :prior_auth_required, null: false, default: false

      t.timestamps
    end

    add_index :benefit_coverage_rules, [ :benefit_plan_id, :level_of_service ],
              unique: true, name: "index_coverage_rules_on_plan_and_service"
  end
end
