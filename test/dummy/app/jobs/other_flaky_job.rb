class OtherFlakyJob < ApplicationJob
  def perform(*) = raise(JobFailure, "Gateway timeout")
end
