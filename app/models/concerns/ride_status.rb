# Shared vocabulary for Ride#status and RideStatusEvent#from_status/#to_status,
# so the audit trail's enum values always line up with the ride's own enum.
# "released" is intentionally not in this list: releasing a claim is a
# transition (claimed -> requested), not a resting state — see Ride#release!.
module RideStatus
  VALUES = %w[
    requested
    claimed
    in_progress
    completed
    cancelled
  ].freeze
end
