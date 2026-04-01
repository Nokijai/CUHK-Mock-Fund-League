class MarketDataRefreshFastJob < ApplicationJob
  queue_as :default

  # Frequent lightweight refresh so prices stay fresh with lower latency.
  def perform
    MarketDataRefreshAllJob.perform_now(profile: "fast")
  end
end
