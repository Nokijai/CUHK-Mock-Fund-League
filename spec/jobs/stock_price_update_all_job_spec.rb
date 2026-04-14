require "rails_helper"

RSpec.describe StockPriceUpdateAllJob, type: :job do
  it "runs update and logs summary counts" do
    service = instance_double(StockPriceService, update_all_prices: { updated: %w[AAPL TSLA], failed: ["BAD"] })
    allow(StockPriceService).to receive(:new).and_return(service)
    allow(Rails.logger).to receive(:info)

    described_class.perform_now

    expect(StockPriceService).to have_received(:new)
    expect(service).to have_received(:update_all_prices)
    expect(Rails.logger).to have_received(:info).with("Starting stock price update...")
    expect(Rails.logger).to have_received(:info).with("Updated: 2, Failed: 1")
  end
end
