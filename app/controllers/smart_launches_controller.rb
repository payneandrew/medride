# Implements both SMART App Launch flows (see SMART App Launch spec, "App
# launch: EHR launch" / "App launch: Standalone launch") against whatever
# FHIR server the user points at — tested against the public SMART Health
# IT sandbox (https://launch.smarthealthit.org), which needs no real client
# registration. A successful launch feeds the same Fhir::PatientImport used
# by EhrImportsController, so this ends in a real imported Patient rather
# than just a demo of the OAuth handshake.
class SmartLaunchesController < ApplicationController
  before_action :require_coordinator!

  # The sandbox doesn't validate client_id against a real registry for its
  # public/PKCE clients, so a fixed demo string is enough to identify us.
  CLIENT_ID = ENV.fetch("SMART_CLIENT_ID", "medride-smart-demo")

  def new
  end

  # Standalone launch: we initiate it ourselves against a known iss, with no
  # launch context yet — see AuthorizationRequest's "launch/patient" scope
  # for how the patient gets picked. Note launch.smarthealthit.org's bare
  # /v/r4/fhir iss doesn't support this (its authorize endpoint demands
  # launch context minted via their launcher UI, even for "standalone") —
  # this action is for a real EHR sandbox's iss that supports launching
  # without that round-trip; see #launch for the path that works against
  # launch.smarthealthit.org.
  def create
    iss = params[:iss].to_s.strip
    return redirect_to new_smart_launch_path, alert: "Enter a FHIR server iss" if iss.blank?

    start_authorization!(iss: iss, launch: nil)
  rescue SmartOnFhir::Configuration::Error => e
    redirect_to new_smart_launch_path, alert: e.message
  end

  # EHR launch entrypoint — this is the exact URL to paste into the SMART
  # Health IT launcher's "App Launch URL" field. The EHR (or the launcher
  # simulating one) redirects the browser here with iss + launch already
  # set, meaning launch context (which patient) is already established on
  # the server side — see AuthorizationRequest's "launch" scope.
  def launch
    iss = params[:iss].to_s.strip
    return redirect_to new_smart_launch_path, alert: "EHR launch is missing the iss parameter" if iss.blank?

    start_authorization!(iss: iss, launch: params[:launch])
  rescue SmartOnFhir::Configuration::Error => e
    redirect_to new_smart_launch_path, alert: e.message
  end

  # The OAuth2 redirect_uri target for both launch types.
  def callback
    unless params[:state].present? && params[:state] == session[:smart_state]
      return redirect_to new_smart_launch_path, alert: "SMART launch state mismatch — please try again"
    end

    token = SmartOnFhir::TokenExchange.call(
      token_endpoint: session[:smart_token_endpoint],
      code: params[:code],
      code_verifier: session[:smart_code_verifier],
      redirect_uri: smart_callback_url,
      client_id: CLIENT_ID
    )

    if token.patient_id.blank?
      return redirect_to new_smart_launch_path, alert: "SMART launch didn't return a patient in context"
    end

    import_patient!(iss: session[:smart_iss], token: token)
  rescue SmartOnFhir::TokenExchange::Error, Fhir::Client::Error => e
    redirect_to new_smart_launch_path, alert: e.message
  ensure
    session.delete(:smart_state)
    session.delete(:smart_code_verifier)
    session.delete(:smart_iss)
    session.delete(:smart_token_endpoint)
  end

  private

  def start_authorization!(iss:, launch:)
    configuration = SmartOnFhir::Configuration.discover(iss)
    authorization = SmartOnFhir::AuthorizationRequest.build(
      iss: iss,
      authorization_endpoint: configuration.authorization_endpoint,
      client_id: CLIENT_ID,
      redirect_uri: smart_callback_url,
      launch: launch
    )

    session[:smart_state] = authorization.state
    session[:smart_code_verifier] = authorization.code_verifier
    session[:smart_iss] = iss
    session[:smart_token_endpoint] = configuration.token_endpoint

    redirect_to authorization.url, allow_other_host: true
  end

  def import_patient!(iss:, token:)
    connection = Fhir::Client.build_connection(base_url: iss, bearer_token: token.access_token)
    fhir_patient = Fhir::Client.new(connection: connection).fetch_patient(token.patient_id)

    if fhir_patient.nil?
      return redirect_to new_smart_launch_path,
        alert: "No FHIR patient found with id \"#{token.patient_id}\" at #{iss}"
    end

    patient = Fhir::PatientImport.call(fhir_patient)

    unless patient.save
      return redirect_to new_smart_launch_path,
        alert: "SMART patient #{token.patient_id} is missing required info " \
               "(#{patient.errors.full_messages.to_sentence}) — this sandbox record is too sparse to import as-is."
    end

    redirect_to new_ride_path(patient_id: patient.id), notice: "Imported #{patient.name} via SMART on FHIR"
  end

  def require_coordinator!
    redirect_to new_identity_path, alert: "Sign in as a coordinator first" unless current_coordinator
  end
end
