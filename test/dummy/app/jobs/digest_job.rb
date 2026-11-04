class DigestJob < ApplicationJob
  queue_as :digests

  def perform(*) = nil
end
