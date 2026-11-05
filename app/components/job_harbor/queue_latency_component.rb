# frozen_string_literal: true

module JobHarbor
  class QueueLatencyComponent < ApplicationComponent
    def initialize(queue:)
      @queue = queue
    end

    def call
      oldest = @queue&.oldest_ready_at
      html_escape(oldest ? time_ago_in_words(oldest) : "—")
    end
  end
end
