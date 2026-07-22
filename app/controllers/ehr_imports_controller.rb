class EhrImportsController < ApplicationController
  before_action :require_coordinator!

  def new
    @patients = Patient.order(:last_name, :first_name)
  end

  # Separate from #new (not just inline on the same page) so the FHIR call
  # only happens when a coordinator actually searches, and results have
  # their own bookmarkable/shareable URL. GET, not POST — this doesn't
  # create anything, just queries the FHIR server.
  def search
    @family_name = params[:family_name].to_s.strip

    if @family_name.present?
      all_matches = fhir_client.search_patients(@family_name)
      # Records too sparse to import (see Patient#importable?) are filtered
      # out here rather than shown-but-disabled — the public HAPI test
      # server has plenty of name-only junk data, and there's nothing a
      # coordinator can do about a record missing its address anyway. We
      # still need the raw count, though: silently going from "20 matches"
      # to "no results" would look like the search itself failed.
      @results = all_matches.select(&:importable?)
      @incomplete_match_count = all_matches.size - @results.size
    else
      @results = []
      @incomplete_match_count = 0
    end
  rescue Fhir::Client::Error => e
    @results = []
    @incomplete_match_count = 0
    flash.now[:alert] = "FHIR server error: #{e.message}"
  end

  def create
    fhir_id = params[:fhir_patient_id].to_s.strip
    fhir_patient = fhir_client.fetch_patient(fhir_id)

    if fhir_patient.nil?
      return redirect_to new_ehr_import_path, alert: "No FHIR patient found with id \"#{fhir_id}\""
    end

    patient = Fhir::PatientImport.call(fhir_patient)

    unless patient.save
      return redirect_to new_ehr_import_path,
        alert: "FHIR patient #{fhir_id} is missing required info (#{patient.errors.full_messages.to_sentence}) " \
               "— this HAPI test-server record is too sparse to import as-is. Try a different patient id."
    end

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

  def import_notice(patient, appointment)
    if appointment
      "Imported #{patient.name} from the EHR — found an appointment on #{appointment.start_time.strftime('%b %-d at %-I:%M%p')}"
    else
      "Imported #{patient.name} from the EHR — no upcoming appointments found"
    end
  end
end
