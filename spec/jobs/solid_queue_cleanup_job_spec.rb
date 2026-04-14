require "rails_helper"

RSpec.describe SolidQueueCleanupJob, type: :job do
  it "clears finished jobs in batches" do
    allow(SolidQueue::Job).to receive(:clear_finished_in_batches)

    described_class.perform_now

    expect(SolidQueue::Job).to have_received(:clear_finished_in_batches).with(sleep_between_batches: 0.3)
  end
end
