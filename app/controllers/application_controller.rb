class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_coordinator, :current_transport_provider

  private

  # No authentication system in this project (out of scope for the domain
  # modeling exercise) — coordinators/providers "sign in" by picking
  # themselves from a list, and we remember the choice in the session.
  def current_coordinator
    return nil if session[:coordinator_id].blank?

    @current_coordinator ||= Coordinator.find_by(id: session[:coordinator_id])
  end

  def current_transport_provider
    return nil if session[:transport_provider_id].blank?

    @current_transport_provider ||= TransportProvider.find_by(id: session[:transport_provider_id])
  end
end
