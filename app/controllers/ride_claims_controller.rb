class RideClaimsController < ApplicationController
  before_action :require_transport_provider!
  before_action :set_ride

  def create
    @ride.claim!(current_transport_provider)
    redirect_to rides_path, notice: "Claimed ride ##{@ride.id}"
  rescue Ride::InvalidTransition, Ride::AlreadyClaimedError => e
    redirect_to rides_path, alert: e.message
  end

  def destroy
    unless @ride.active_claim&.transport_provider == current_transport_provider
      return redirect_to rides_path, alert: "You don't hold the active claim on this ride"
    end

    @ride.release!(actor: current_transport_provider)
    redirect_to rides_path, notice: "Released ride ##{@ride.id} back to the marketplace"
  rescue Ride::InvalidTransition => e
    redirect_to rides_path, alert: e.message
  end

  private

  def set_ride
    @ride = Ride.find(params[:ride_id])
  end

  def require_transport_provider!
    redirect_to new_identity_path, alert: "Sign in as a transport provider first" unless current_transport_provider
  end
end
