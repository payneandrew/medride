namespace :webhooks do
  desc "Fire a fake ride_status webhook at the running app, signed like a real vendor would. Usage: bin/rails 'webhooks:fire_ride_status[ride_id,status,transport_provider_id]'"
  task :fire_ride_status, [ :ride_id, :status, :transport_provider_id ] => :environment do |_, args|
    require "net/http"

    ride_id = args[:ride_id] || abort("usage: bin/rails 'webhooks:fire_ride_status[ride_id,status,transport_provider_id]'")
    status = args[:status] || abort("usage: bin/rails 'webhooks:fire_ride_status[ride_id,status,transport_provider_id]'")

    payload = {
      event_id: SecureRandom.uuid,
      ride_id: ride_id.to_i,
      status: status,
      transport_provider_id: args[:transport_provider_id]&.to_i,
      occurred_at: Time.current.iso8601
    }.compact.to_json

    uri = URI.join(ENV.fetch("MEDRIDE_URL", "http://localhost:3000"), "/webhooks/ride_status")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Medride-Signature"] = RideStatusWebhookSigner.sign(payload)
    request.body = payload

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
    puts "POST #{uri} #{payload} => #{response.code} #{response.body}"
  end

  desc "Fire a fake Uber Health ride-status webhook, using their (fake) status vocabulary and their own ride id. Usage: bin/rails 'webhooks:fire_uber_health_ride_status[external_ride_id,status]'"
  task :fire_uber_health_ride_status, [ :external_ride_id, :status ] => :environment do |_, args|
    require "net/http"

    external_ride_id = args[:external_ride_id] || abort("usage: bin/rails 'webhooks:fire_uber_health_ride_status[external_ride_id,status]'")
    status = args[:status] || abort("usage: bin/rails 'webhooks:fire_uber_health_ride_status[external_ride_id,status]' (status one of: arriving, trip_started, trip_completed, canceled)")

    payload = {
      event_id: SecureRandom.uuid,
      ride_id: external_ride_id,
      status: status,
      timestamp: Time.current.iso8601
    }.to_json

    uri = URI.join(ENV.fetch("MEDRIDE_URL", "http://localhost:3000"), "/webhooks/uber_health_ride_status")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Uber-Signature"] = UberHealth::WebhookSigner.sign(payload)
    request.body = payload

    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
    puts "POST #{uri} #{payload} => #{response.code} #{response.body}"
  end
end
