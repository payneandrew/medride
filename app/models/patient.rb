class Patient < ApplicationRecord
  # What clinical need drives this patient's transport, independent of what
  # gets booked on any given ride. RightSizingCheck uses this (not the
  # requested level_of_service) as the source of truth for what's medically
  # justified.
  enum :mobility_needs, %w[ambulatory wheelchair stretcher bls_needed], default: "ambulatory"

  belongs_to :benefit_plan, optional: true
  has_many :rides, dependent: :restrict_with_error

  validates :first_name, :last_name, :phone, presence: true
  validates :home_address_line1, :home_city, :home_state, :home_zip, presence: true
  validates :fhir_id, uniqueness: true, allow_nil: true

  def name
    "#{first_name} #{last_name}"
  end

  def home_address
    [ home_address_line1, home_address_line2, home_city, home_state, home_zip ].compact_blank.join(", ")
  end
end
