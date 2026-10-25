class FlakyPaymentJob < ApplicationJob
  class GatewayError < StandardError; end

  def perform(order_id)
    raise GatewayError, "Card declined for order #{order_id}"
  end
end
