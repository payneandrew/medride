class TransportProviderCapability < ApplicationRecord
  include LevelOfService

  belongs_to :transport_provider

  enum :capability, LevelOfService::VALUES

  validates :capability, uniqueness: { scope: :transport_provider_id }
end
