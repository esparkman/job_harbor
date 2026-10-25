# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class DashboardStatsTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    test "a queue paused before any job arrived counts toward the dashboard's queue total" do
      enqueue_job(ReportJob, "weekly", queue: "default")
      SolidQueue::Pause.create!(queue_name: "low_priority")

      assert_equal 2, DashboardStats.new.queues_count
    end

    test "a queue that is both paused and has jobs counts once" do
      enqueue_job(ReportJob, "weekly", queue: "default")
      SolidQueue::Pause.create!(queue_name: "default")

      assert_equal 1, DashboardStats.new.queues_count
    end

    test "with no jobs and no paused queues the dashboard shows zero queues" do
      assert_equal 0, DashboardStats.new.queues_count
    end
  end
end
