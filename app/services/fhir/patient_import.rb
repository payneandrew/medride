module Fhir
  # Maps a Fhir::Patient onto our local Patient record, matched on fhir_id.
  # Shared by EhrImportsController (unauthenticated HAPI test-server lookup)
  # and SmartLaunchesController (SMART-authenticated, context-scoped lookup)
  # — both end up with the same Fhir::Patient struct and need the same
  # field mapping, so it lives in one place rather than two copies drifting
  # apart.
  #
  # In a real system this lookup would go through Patient.identifier
  # (system + value) — e.g. the MRN issued by *this* facility's identifier
  # system — rather than the FHIR resource's own server-assigned id, since
  # the same human can carry different FHIR ids across EHR instances but
  # keeps the same MRN within one health system.
  #
  # Deliberately no "Unknown"/placeholder fallback for missing fields:
  # silently inventing fake demographic data would let garbage flow straight
  # into a ride booking. Better to fail the import loudly (caller checks
  # patient.save) and have the coordinator try a different patient —
  # Patient's own presence validations are what catch this.
  class PatientImport
    def self.call(fhir_patient)
      patient = ::Patient.find_or_initialize_by(fhir_id: fhir_patient.fhir_id)
      patient.first_name = fhir_patient.given_name.presence || patient.first_name
      patient.last_name = fhir_patient.family_name.presence || patient.last_name
      patient.phone = fhir_patient.phone.presence || patient.phone
      patient.home_address_line1 = fhir_patient.address_line1.presence || patient.home_address_line1
      patient.home_city = fhir_patient.city.presence || patient.home_city
      patient.home_state = fhir_patient.state.presence || patient.home_state
      patient.home_zip = fhir_patient.postal_code.presence || patient.home_zip
      patient
    end
  end
end
