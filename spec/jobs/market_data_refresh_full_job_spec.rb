require "rails_helper"

RSpec.describe MarketDataRefreshFullJob, type: :job do
  it "delegates to all refresh job with full profile" do
    allow(MarketDataRefreshAllJob).to receive(:perform_now)

    described_class.perform_now

    expect(MarketDataRefreshAllJob).to have_received(:perform_now).with(profile: "full")
  end
end
