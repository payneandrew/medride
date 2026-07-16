class BenefitCoverageRule < ApplicationRecord
  include LevelOfService

  belongs_to :benefit_plan

  enum :level_of_service, LevelOfService::VALUES

  validates :level_of_service, uniqueness: { scope: :benefit_plan_id }
end
