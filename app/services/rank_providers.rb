# Layers scoring/ranking on top of MatchRide's eligibility filter — deliberately
# a separate service rather than folded into MatchRide, mirroring a common
# marketplace-matching split: candidate generation (who's eligible at all)
# vs. ranking (given eligible candidates, who's the best fit). Composes
# three independent 0.0-1.0 scores into one weighted number; the weights
# are a product decision, not an engineering one, so they're named
# constants here rather than buried in a formula.
class RankProviders
  RELIABILITY_WEIGHT = 0.40
  DISTANCE_WEIGHT = 0.35
  PRICE_WEIGHT = 0.25

  Result = Struct.new(
    :transport_provider, :score,
    :reliability_score, :distance_score, :distance_miles,
    :price_score, :estimated_price_cents,
    keyword_init: true
  )

  def self.call(ride, candidates = MatchRide.call(ride))
    new(ride, candidates).call
  end

  def initialize(ride, candidates)
    @ride = ride
    @candidates = candidates
  end

  def call
    candidates.map { |provider| score_for(provider) }.sort_by { |result| -result.score }
  end

  private

  attr_reader :ride, :candidates

  def score_for(provider)
    reliability_score = ProviderRanking::ReliabilityScore.call(provider)
    distance = ProviderRanking::DistanceScore.new(ride, provider)
    price = ProviderRanking::PriceScore.new(ride, provider)

    composite = (reliability_score * RELIABILITY_WEIGHT) +
                (distance.score * DISTANCE_WEIGHT) +
                (price.score * PRICE_WEIGHT)

    Result.new(
      transport_provider: provider,
      score: composite,
      reliability_score: reliability_score,
      distance_score: distance.score,
      distance_miles: distance.miles,
      price_score: price.score,
      estimated_price_cents: price.estimated_price_cents
    )
  end
end
