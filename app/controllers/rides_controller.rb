class RidesController < ApplicationController
  before_action :require_coordinator!, only: [ :new, :create ]
  before_action :require_transport_provider!, only: [ :start, :complete ]
  before_action :set_ride, only: [ :show, :start, :complete ]

  def index
    if current_transport_provider
      # "Claimable" mirrors MatchRide's logic (service area covers pickup
      # zip AND capability matches level_of_service) but queried directly
      # against Ride rather than via MatchRide, since MatchRide answers
      # "which providers fit this ride" and here we need the inverse
      # question, "which requested rides fit me."
      @claimable_rides = Ride.requested
        .where(pickup_zip: current_transport_provider.service_area)
        .where(level_of_service: current_transport_provider.transport_provider_capabilities.select(:capability))
        .order(:scheduled_at)
      # Where does *this* provider stand against whoever else could take
      # each ride — not just "am I eligible" (that's already true for
      # everything in @claimable_rides) but "am I actually the best fit."
      @rankings_by_ride_id = @claimable_rides.index_with { |ride| RankProviders.call(ride) }
      @my_rides = Ride.joins(:ride_claims)
        .where(ride_claims: { transport_provider_id: current_transport_provider.id, released_at: nil })
        .order(:scheduled_at)
    elsif current_coordinator
      @rides = current_coordinator.rides.includes(:patient).order(scheduled_at: :desc)
    else
      @rides = Ride.none
    end
  end

  def show
    @ranked_providers = RankProviders.call(@ride) if current_coordinator && @ride.requested?
  end

  def start
    authorize_active_claim!
    @ride.start!(actor: current_transport_provider)
    respond_with_ride_update(notice: "Ride started")
  rescue Ride::InvalidTransition => e
    respond_with_failure(e)
  end

  def complete
    authorize_active_claim!
    @ride.complete!(actor: current_transport_provider)
    respond_with_ride_update(notice: "Ride completed")
  rescue Ride::InvalidTransition => e
    respond_with_failure(e)
  end

  def new
    patient = Patient.find_by(id: params[:patient_id])

    @ride = Ride.new(
      patient_id: patient&.id,
      scheduled_at: params[:scheduled_at].presence,
      # Pickup defaults to the patient's home address (the common case for
      # NEMT); dropoff is left for the coordinator to fill in unless we know
      # it from an imported appointment, in which case it's just a
      # placeholder — HAPI's Appointment resource doesn't carry a location
      # address here, only a Location reference we'd have to fetch to make
      # this real.
      pickup_address_line1: patient&.home_address_line1,
      pickup_city: patient&.home_city,
      pickup_state: patient&.home_state,
      pickup_zip: patient&.home_zip,
      dropoff_address_line1: params[:prefill_dropoff] ? "TBD - confirm destination with facility" : nil
    )
  end

  def create
    @ride = Ride.new(ride_params)
    @ride.coordinator = current_coordinator
    apply_eligibility_check(@ride)

    if @ride.save
      redirect_to @ride, notice: "Ride booked" + (@ride.needs_authorization? ? " — needs prior authorization" : "")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_ride
    @ride = Ride.find(params[:id])
  end

  # Runs the stubbed payer eligibility check at booking time: a
  # prior-auth-required level_of_service still books (status stays
  # "requested") but is flagged for a human to clear before a provider
  # should claim it, mirroring a real CoverageEligibilityResponse gate.
  # RightSizingCheck (see Ride#level_of_service_is_right_sized) is the
  # other half of booking policy — that one's a hard reject, enforced as a
  # model validation rather than here, since "is this even a valid ride"
  # should hold no matter what code path creates one.
  def apply_eligibility_check(ride)
    return if ride.patient.nil? || ride.level_of_service.nil?

    response = EligibilityCheck.call(Fhir::EligibilityRequest.new(patient: ride.patient, level_of_service: ride.level_of_service))
    ride.needs_authorization = response.prior_auth_required?
  end

  def require_coordinator!
    redirect_to new_identity_path, alert: "Sign in as a coordinator first" unless current_coordinator
  end

  def require_transport_provider!
    redirect_to new_identity_path, alert: "Sign in as a transport provider first" unless current_transport_provider
  end

  def authorize_active_claim!
    return if @ride.active_claim&.transport_provider == current_transport_provider

    raise Ride::InvalidTransition, "you don't hold the active claim on this ride"
  end

  # Start/complete can be triggered from either the ride show page or a row
  # in the provider dashboard's "My active rides" list — the turbo_stream
  # response updates both possible targets; whichever isn't on the current
  # page is silently a no-op (Turbo just skips targets it can't find).
  def respond_with_ride_update(notice:)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(@ride, :header), partial: "rides/header", locals: { ride: @ride }),
          turbo_stream.replace(helpers.dom_id(@ride, :active), partial: "rides/active_ride_row", locals: { ride: @ride }),
          turbo_stream.replace(helpers.dom_id(@ride, :audit_trail), partial: "rides/audit_trail", locals: { ride: @ride }),
          turbo_stream.replace("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to @ride, notice: notice }
    end
  end

  def respond_with_failure(error)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = error.message
        render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
      end
      format.html { redirect_to @ride, alert: error.message }
    end
  end

  def ride_params
    params.require(:ride).permit(
      :patient_id, :scheduled_at, :level_of_service,
      :pickup_address_line1, :pickup_city, :pickup_state, :pickup_zip, :pickup_lat, :pickup_lng,
      :dropoff_address_line1, :dropoff_city, :dropoff_state, :dropoff_zip, :dropoff_lat, :dropoff_lng
    )
  end
end
