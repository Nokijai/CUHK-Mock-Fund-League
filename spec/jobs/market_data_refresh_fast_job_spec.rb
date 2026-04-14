require "rails_helper"

RSpec.describe MarketDataRefreshFastJob, type: :job do
  it "delegates to all refresh job with fast profile" do
    allow(MarketDataRefreshAllJob).to receive(:perform_now)

    described_class.perform_now

    expect(MarketDataRefreshAllJob).to have_received(:perform_now).with(profile: "fast")
  end
end
