# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class WorkerCardComponentTest < ViewComponentTestCase
    include SolidQueueTestHelper

    test "lists the queues a worker polls, trimming spaces and dropping blanks" do
      render_inline(WorkerCardComponent.new(worker: register_worker(name: "w", queues: "default, mailers,,")))

      assert_equal %w[default mailers], fragment.css("code").map { |c| c.text.strip }
      assert_includes @rendered, "Queues:"
    end

    test "shows no queue section for a process that records no queues" do
      render_inline(WorkerCardComponent.new(worker: register_worker(name: "w", kind: "Supervisor")))

      refute_includes @rendered, "Queues:"
    end

    test "labels the process kind and marks a long-silent process Stale, not Blocked" do
      render_inline(WorkerCardComponent.new(worker: register_worker(name: "w", kind: "Dispatcher", heartbeat_at: 1.hour.ago)))

      assert_equal "Dispatcher", fragment.at_css("[data-kind]").text.strip
      assert_includes @rendered, "Stale"
      refute_includes @rendered, "Blocked"
    end
  end
end
