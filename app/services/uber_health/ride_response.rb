module UberHealth
  # What we keep from a real Uber Health "create ride" response. Their real
  # payload carries a lot more (driver name/photo/vehicle, live location) —
  # we only need enough to record the claim and correlate later webhooks.
  RideResponse = Struct.new(:external_ride_id, :status, :eta_minutes, keyword_init: true)
end
