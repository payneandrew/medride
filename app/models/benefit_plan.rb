class BenefitPlan < ApplicationRecord
  has_many :benefit_coverage_rules, dependent: :destroy
  has_many :patients, dependent: :nullify

  validates :name, presence: true

  def coverage_rule_for(level_of_service)
    benefit_coverage_rules.find_by(level_of_service: level_of_service)
  end
end
