class SolidQueueCleanupJob < ApplicationJob
  queue_as :default

  # Run built-in finished-job cleanup without relying on recurring `command:` tasks.
  # This avoids scheduler boot failures on environments with legacy recurring_task schema.
  def perform
    SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)
  end
end
