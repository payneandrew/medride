module Fhir
  Appointment = Struct.new(
    :fhir_id, :status, :start_time, :description, :patient_fhir_id,
    keyword_init: true
  )
end
