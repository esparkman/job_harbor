class BrokenExportJob < ApplicationJob
  def perform(*)
    raise FlakyPaymentJob::GatewayError, "Export crashed"
  end
end
