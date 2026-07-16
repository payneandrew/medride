module Fhir
  # Mirrors the part of a FHIR CoverageEligibilityResponse.insurance.item
  # that we act on: benefit.allowed (-> remaining_trips), excluded (->
  # !covered), and authorizationRequired. A real response also carries
  # outcome ("complete"/"error"), disposition text, and one item per benefit
  # category rather than a single flattened result.
  EligibilityResponse = Struct.new(
    :covered, :remaining_trips, :prior_auth_required,
    keyword_init: true
  ) do
    def covered?
      covered
    end

    def prior_auth_required?
      prior_auth_required
    end
  end
end
