class ReportJob < ApplicationJob
  # Recurring tasks only record a RecurringExecution when the job runs on Solid Queue.
  self.queue_adapter = :solid_queue

  def perform(*) = nil
end
