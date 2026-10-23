# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class ProcessesTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup { freeze_time }

    test "alive covers every kind with a fresh heartbeat and live_workers only the workers" do
      worker = register_worker(name: "w")
      supervisor = register_worker(name: "s", kind: "Supervisor")
      register_worker(name: "old", heartbeat_at: 10.minutes.ago)

      assert_equal [ worker, supervisor ].sort_by(&:id), Processes.alive.sort_by(&:id)
      assert_equal [ worker ], Processes.live_workers.to_a
    end

    test "a heartbeat exactly at the threshold is stale, matching Solid Queue's prunable scope" do
      edge = register_worker(name: "edge", heartbeat_at: SolidQueue.process_alive_threshold.ago)

      assert_includes SolidQueue::Process.prunable, edge
      refute_includes Processes.alive, edge
      refute Processes.alive?(edge)
    end

    test "follows SolidQueue.process_alive_threshold" do
      process = register_worker(name: "w", heartbeat_at: 2.minutes.ago)
      original = SolidQueue.process_alive_threshold

      SolidQueue.process_alive_threshold = 1.minute
      refute Processes.alive?(process)
      SolidQueue.process_alive_threshold = 3.minutes
      assert Processes.alive?(process)
    ensure
      SolidQueue.process_alive_threshold = original
    end
  end
end
