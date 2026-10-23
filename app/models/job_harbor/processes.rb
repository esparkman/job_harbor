# frozen_string_literal: true

module JobHarbor
  # Liveness by SQ's process_alive_threshold.
  module Processes
    module_function

    # Inverse of SolidQueue::Process.prunable.
    def alive
      SolidQueue::Process.where.not(last_heartbeat_at: ..cutoff)
    end

    def live_workers
      alive.where(kind: "Worker")
    end

    def alive?(process)
      process.last_heartbeat_at.present? && process.last_heartbeat_at > cutoff
    end

    def cutoff
      SolidQueue.process_alive_threshold.ago
    end
  end
end
