class TransportProvider < ApplicationRecord
  has_many :transport_provider_capabilities, dependent: :destroy
  has_many :ride_claims, dependent: :restrict_with_error

  validates :name, :phone, presence: true

  def capable_of?(level_of_service)
    transport_provider_capabilities.exists?(capability: level_of_service)
  end

  def covers_zip?(zip)
    service_area.include?(zip)
  end
end
