class MarketDataRefreshFullJob < ApplicationJob
  queue_as :default

  # Less frequent deep refresh to keep wider candle history reasonably current.
  def perform
    MarketDataRefreshAllJob.perform_now(profile: "full")
  end
end
