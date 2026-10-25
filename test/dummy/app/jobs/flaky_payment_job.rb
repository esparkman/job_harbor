class FlakyPaymentJob < ApplicationJob
  def perform(order_id)
    raise JobFailure, "Card declined for order #{order_id}"
  end
end
