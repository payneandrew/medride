class RideClaimsController < ApplicationController
  before_action :require_transport_provider!
  before_action :set_ride

  def create
    @ride.claim!(current_transport_provider)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Claimed ride ##{@ride.id}"
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@ride, :claimable)),
          turbo_stream.prepend("my_active_rides", partial: "rides/active_ride_row", locals: { ride: @ride }),
          turbo_stream.replace(helpers.dom_id(@ride, :header), partial: "rides/header", locals: { ride: @ride }),
          turbo_stream.replace(helpers.dom_id(@ride, :audit_trail), partial: "rides/audit_trail", locals: { ride: @ride }),
          turbo_stream.replace("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to rides_path, notice: "Claimed ride ##{@ride.id}" }
    end
  rescue Ride::InvalidTransition, Ride::AlreadyClaimedError => e
    handle_failure(e, fallback_path: rides_path)
  end

  def destroy
    unless @ride.active_claim&.transport_provider == current_transport_provider
      return handle_failure("You don't hold the active claim on this ride", fallback_path: rides_path)
    end

    @ride.release!(actor: current_transport_provider)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Released ride ##{@ride.id} back to the marketplace"
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@ride, :active)),
          turbo_stream.prepend("claimable_rides", partial: "rides/claimable_row", locals: { ride: @ride, ranking: RankProviders.call(@ride) }),
          turbo_stream.replace(helpers.dom_id(@ride, :header), partial: "rides/header", locals: { ride: @ride }),
          turbo_stream.replace(helpers.dom_id(@ride, :audit_trail), partial: "rides/audit_trail", locals: { ride: @ride }),
          turbo_stream.replace("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to rides_path, notice: "Released ride ##{@ride.id} back to the marketplace" }
    end
  rescue Ride::InvalidTransition => e
    handle_failure(e, fallback_path: rides_path)
  end

  private

  def set_ride
    @ride = Ride.find(params[:ride_id])
  end

  def require_transport_provider!
    redirect_to new_identity_path, alert: "Sign in as a transport provider first" unless current_transport_provider
  end

  def handle_failure(error, fallback_path:)
    message = error.respond_to?(:message) ? error.message : error

    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = message
        render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
      end
      format.html { redirect_to fallback_path, alert: message }
    end
  end
end
