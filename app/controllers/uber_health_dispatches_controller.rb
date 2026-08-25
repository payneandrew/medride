class UberHealthDispatchesController < ApplicationController
  before_action :require_coordinator!
  before_action :set_ride

  def create
    response = UberHealth::DispatchRide.call(@ride)
    notice = "Dispatched to Uber Health — ETA #{response.eta_minutes} min (external ride #{response.external_ride_id})"

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(@ride, :header), partial: "rides/header", locals: { ride: @ride }),
          turbo_stream.replace(helpers.dom_id(@ride, :audit_trail), partial: "rides/audit_trail", locals: { ride: @ride }),
          turbo_stream.replace("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to @ride, notice: notice }
    end
  rescue Ride::InvalidTransition, UberHealth::Client::UnsupportedLevelOfServiceError => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = e.message
        render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
      end
      format.html { redirect_to @ride, alert: e.message }
    end
  end

  private

  def set_ride
    @ride = Ride.find(params[:ride_id])
  end

  def require_coordinator!
    redirect_to new_identity_path, alert: "Sign in as a coordinator first" unless current_coordinator
  end
end
