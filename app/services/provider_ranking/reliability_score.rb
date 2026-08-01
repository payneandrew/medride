module ProviderRanking
  # Blends two real, historical signals into one 0.0-1.0 score:
  # - completion rate: of rides this provider saw through to a resolution
  #   (completed or cancelled), how many did they actually complete?
  # - on-time rate: of the ones they completed, how often did they start
  #   (claimed -> in_progress) at or before the scheduled time?
  #
  # In production this would be a materialized/cached column updated async
  # as rides resolve, not recomputed from scratch on every ranking call —
  # fine for this app's scale, not for a real marketplace's.
  class ReliabilityScore
    ON_TIME_GRACE_PERIOD = 15.minutes
    COMPLETION_WEIGHT = 0.6
    ON_TIME_WEIGHT = 0.4

    # A provider with no resolved ride history yet is unproven, not bad —
    # scoring them at 0 would permanently rank new providers last no matter
    # how reliable they turn out to be. This is a neutral prior, not a
    # measurement.
    DEFAULT_SCORE = 0.75

    def self.call(transport_provider)
      new(transport_provider).call
    end

    def initialize(transport_provider)
      @transport_provider = transport_provider
    end

    def call
      return DEFAULT_SCORE if total_resolved.zero?

      (completion_rate * COMPLETION_WEIGHT) + (on_time_rate * ON_TIME_WEIGHT)
    end

    private

    attr_reader :transport_provider

    def resolved_rides
      @resolved_rides ||= Ride
        .joins(:ride_claims)
        .where(ride_claims: { transport_provider_id: transport_provider.id })
        .where(status: %w[completed cancelled])
        .distinct
    end

    def total_resolved
      @total_resolved ||= resolved_rides.count
    end

    def completion_rate
      resolved_rides.where(status: "completed").count.to_f / total_resolved
    end

    def on_time_rate
      starts = RideStatusEvent
        .joins(:ride)
        .where(ride_id: resolved_rides.where(status: "completed").select(:id))
        .where(to_status: "in_progress")
        .pluck("ride_status_events.occurred_at", "rides.scheduled_at")

      return DEFAULT_SCORE if starts.empty?

      on_time = starts.count { |occurred_at, scheduled_at| occurred_at <= scheduled_at + ON_TIME_GRACE_PERIOD }
      on_time.to_f / starts.size
    end
  end
end
