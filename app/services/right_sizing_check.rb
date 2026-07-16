# Table-driven ceiling on what level_of_service a patient's mobility_needs
# can justify. This mirrors real NEMT utilization management: the whole
# point is preventing over-ordering expensive transport (e.g. booking a BLS
# ambulance for a patient who only needs a wheelchair van) — not preventing
# under-ordering, which is a clinical/safety judgment call this simple table
# doesn't try to make.
class RightSizingCheck
  MAX_LEVEL_OF_SERVICE_BY_MOBILITY_NEED = {
    "ambulatory" => "medical_sedan",
    "wheelchair" => "wheelchair_van",
    "stretcher" => "stretcher_van",
    "bls_needed" => "bls_ambulance"
  }.freeze

  def self.call(patient:, level_of_service:)
    new(patient: patient, level_of_service: level_of_service).call
  end

  def initialize(patient:, level_of_service:)
    @patient = patient
    @level_of_service = level_of_service.to_s
  end

  def call
    requested_rank <= max_allowed_rank
  end

  private

  attr_reader :patient, :level_of_service

  def requested_rank
    LevelOfService::VALUES.index(level_of_service)
  end

  def max_allowed_rank
    ceiling = MAX_LEVEL_OF_SERVICE_BY_MOBILITY_NEED.fetch(patient.mobility_needs)
    LevelOfService::VALUES.index(ceiling)
  end
end
