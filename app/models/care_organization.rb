class CareOrganization < ApplicationRecord
  enum :org_type, %w[hospital health_plan]

  has_many :coordinators, dependent: :destroy

  validates :name, presence: true
end
