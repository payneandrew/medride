# Shared vocabulary for vehicle/service tiers, ordered cheapest to most
# clinically intensive. TransportProviderCapability#capability,
# Ride#level_of_service, and BenefitCoverageRule#level_of_service all enum
# off this same array (via Rails' positional-index enum), so the three stay
# in lockstep and ordinal comparisons (as used by RightSizingCheck) mean the
# same thing everywhere.
module LevelOfService
  VALUES = %w[
    rideshare
    medical_sedan
    wheelchair_van
    stretcher_van
    bls_ambulance
  ].freeze
end
