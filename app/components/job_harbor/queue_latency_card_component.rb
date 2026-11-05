# frozen_string_literal: true

module JobHarbor
  # The dashboard card for the unpaused queue that has waited longest, or a blank card when none is waiting.
  class QueueLatencyCardComponent < ApplicationComponent
    def initialize(queue:)
      @queue = queue
    end

    def call
      render StatCardComponent.new(
        label: "Queue Latency",
        value: render(QueueLatencyComponent.new(queue: @queue)),
        link: (queue_path(@queue.name) if @queue),
        detail: @queue&.name
      )
    end
  end
end
