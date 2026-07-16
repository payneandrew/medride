class CreateBenefitPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :benefit_plans do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
