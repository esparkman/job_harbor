# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class RecurringTaskQueueTest < ActiveSupport::TestCase
    test "a queue set on the task wins over the job class's queue" do
      assert_equal "reports", queue_for(class_name: "DigestJob", queue_name: "reports")
    end

    test "a task without a queue runs on its job class's queue" do
      assert_equal "digests", queue_for(class_name: "DigestJob")
      assert_equal "default", queue_for(class_name: "ReportJob")
    end

    test "a command task runs on Solid Queue's recurring job queue" do
      assert_equal "solid_queue_recurring", queue_for(command: "Session.sweep")
    end

    test "a task whose job class is not defined in this app has no known queue" do
      assert_nil queue_for(class_name: "MissingJob")
    end

    test "a job class whose queue block raises has no known queue" do
      job_class = Class.new(ApplicationJob) { queue_as { raise "needs arguments" } }
      stub_const("ExplodingQueueJob", job_class) do
        assert_nil queue_for(class_name: "ExplodingQueueJob")
      end
    end

    private

    def queue_for(**attributes)
      task = SolidQueue::RecurringTask.new(key: "task", schedule: "every hour", **attributes)
      RecurringTaskQueue.new(task).name
    end

    def stub_const(name, value)
      Object.const_set(name, value)
      yield
    ensure
      Object.send(:remove_const, name)
    end
  end
end
