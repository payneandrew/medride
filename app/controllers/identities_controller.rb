class IdentitiesController < ApplicationController
  def new
    @coordinators = Coordinator.order(:name)
    @transport_providers = TransportProvider.order(:name)
  end

  def create
    if params[:coordinator_id].present?
      reset_session
      session[:coordinator_id] = params[:coordinator_id]
      redirect_to new_ehr_import_path, notice: "Signed in as coordinator"
    elsif params[:transport_provider_id].present?
      reset_session
      session[:transport_provider_id] = params[:transport_provider_id]
      redirect_to rides_path, notice: "Signed in as provider"
    else
      redirect_to new_identity_path, alert: "Pick a coordinator or provider"
    end
  end

  def destroy
    reset_session
    redirect_to new_identity_path
  end
end
