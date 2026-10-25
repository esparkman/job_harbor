# frozen_string_literal: true

module JobHarbor
  module Queues
    # Pauses a queue by name, which is how an operator pauses one that has no jobs yet.
    class PausesController < ApplicationController
      def create
        name = params[:name].try(:strip).presence

        if name.nil?
          redirect_to queues_path, alert: "Enter a queue name."
        elsif name.length > QueueStats::MAX_NAME_LENGTH
          redirect_to queues_path, alert: "Queue name must be #{QueueStats::MAX_NAME_LENGTH} characters or fewer."
        elsif name.match?(/[[:cntrl:]]/)
          redirect_to queues_path, alert: "Queue name can't contain control characters."
        else
          pause(QueueStats.new(name))
        end
      end

      private

      def pause(queue)
        if queue.paused?
          redirect_to queues_path, notice: "Queue '#{queue.name}' is already paused."
        else
          queue.pause
          redirect_to queues_path, notice: "Queue '#{queue.name}' has been paused."
        end
      end
    end
  end
end
