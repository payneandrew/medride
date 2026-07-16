class EhrImportsController < ApplicationController
  before_action :require_coordinator!

  def new
  end

  def create
    fhir_id = params[:fhir_patient_id].to_s.strip
    fhir_patient = fhir_client.fetch_patient(fhir_id)

    if fhir_patient.nil?
      return redirect_to new_ehr_import_path, alert: "No FHIR patient found with id \"#{fhir_id}\""
    end

    patient = upsert_patient(fhir_patient)
    appointment = upcoming_appointment_for(fhir_id)

    redirect_to new_ride_path(
      patient_id: patient.id,
      scheduled_at: appointment&.start_time,
      prefill_dropoff: appointment ? "1" : nil
    ), notice: import_notice(patient, appointment)
  rescue Fhir::Client::Error => e
    redirect_to new_ehr_import_path, alert: "FHIR server error: #{e.message}"
  end

  private

  def fhir_client
    @fhir_client ||= Fhir::Client.new
  end

  def require_coordinator!
    redirect_to new_identity_path, alert: "Sign in as a coordinator first" unless current_coordinator
  end

  def upcoming_appointment_for(fhir_id)
    fhir_client.fetch_appointments(fhir_id)
      .select { |a| a.start_time&.future? }
      .min_by(&:start_time)
  end

  # Matched on fhir_id, mapping FHIR Patient fields onto our local record.
  # In a real system this lookup would go through Patient.identifier
  # (system + value) — e.g. the MRN issued by *this* facility's identifier
  # system — rather than the FHIR resource's own server-assigned id, since
  # the same human can carry different FHIR ids across EHR instances but
  # keeps the same MRN within one health system.
  def upsert_patient(fhir_patient)
    patient = Patient.find_or_initialize_by(fhir_id: fhir_patient.fhir_id)
    patient.first_name = fhir_patient.given_name.presence || patient.first_name.presence || "Unknown"
    patient.last_name = fhir_patient.family_name.presence || patient.last_name.presence || "Unknown"
    patient.phone = fhir_patient.phone.presence || patient.phone.presence || "unknown"
    patient.home_address_line1 = fhir_patient.address_line1.presence || patient.home_address_line1.presence || "unknown"
    patient.home_city = fhir_patient.city.presence || patient.home_city.presence || "unknown"
    patient.home_state = fhir_patient.state.presence || patient.home_state.presence || "unknown"
    patient.home_zip = fhir_patient.postal_code.presence || patient.home_zip.presence || "unknown"
    patient.save!
    patient
  end

  def import_notice(patient, appointment)
    if appointment
      "Imported #{patient.name} from the EHR — found an appointment on #{appointment.start_time.strftime('%b %-d at %-I:%M%p')}"
    else
      "Imported #{patient.name} from the EHR — no upcoming appointments found"
    end
  end
end
