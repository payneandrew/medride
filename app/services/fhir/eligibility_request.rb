module Fhir
  # Mirrors the fields of a FHIR CoverageEligibilityRequest that actually
  # matter for this check: who (patient), what benefit category are we
  # asking about (here, level_of_service standing in for a benefit
  # category code), and when. A real request also carries a purpose
  # ("benefits" vs "discovery"), an insurer reference, and item[] detail —
  # omitted since EligibilityCheck only needs to answer one question at a
  # time.
  EligibilityRequest = Struct.new(:patient, :level_of_service, keyword_init: true)
end
