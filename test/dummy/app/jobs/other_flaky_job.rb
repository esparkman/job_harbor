class OtherFlakyJob < ApplicationJob
  def perform(*) = raise(FlakyPaymentJob::GatewayError, "Gateway timeout")
end
