class UberHealthDispatchesController < ApplicationController
  before_action :require_coordinator!
  before_action :set_ride

  def create
    response = UberHealth::DispatchRide.call(@ride)
    redirect_to @ride, notice: "Dispatched to Uber Health — ETA #{response.eta_minutes} min (external ride #{response.external_ride_id})"
  rescue Ride::InvalidTransition, UberHealth::Client::UnsupportedLevelOfServiceError => e
    redirect_to @ride, alert: e.message
  end

  private

  def set_ride
    @ride = Ride.find(params[:ride_id])
  end

  def require_coordinator!
    redirect_to new_identity_path, alert: "Sign in as a coordinator first" unless current_coordinator
  end
end
