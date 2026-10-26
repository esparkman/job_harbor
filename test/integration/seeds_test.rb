require "test_helper"

class SeedsTest < ActionDispatch::IntegrationTest
  setup do
    capture_io { Rails.application.load_seed }
  end

  test "seeded jobs keep their Active Job payload" do
    assert_operator SolidQueue::Job.count, :>, 0

    SolidQueue::Job.find_each do |job|
      assert_kind_of Hash, job.arguments, "seeded #{job.class_name} arguments are double-encoded"
      assert_kind_of Array, job.arguments["arguments"]
    end
  end

  test "seeded failed executions keep their error details" do
    assert_operator SolidQueue::FailedExecution.count, :>, 0

    SolidQueue::FailedExecution.find_each do |failed|
      assert_kind_of Hash, failed.error, "seeded failed execution error is double-encoded"
      assert failed.error["exception_class"].present?
    end
  end

  test "seeded recurring tasks have no arguments" do
    assert_operator SolidQueue::RecurringTask.count, :>, 0

    SolidQueue::RecurringTask.find_each do |task|
      assert_equal [], task.arguments, "seeded #{task.key} arguments are double-encoded"
    end
  end

  test "seeded processes keep their metadata" do
    assert_operator SolidQueue::Process.count, :>, 0

    SolidQueue::Process.find_each do |process|
      assert_kind_of Hash, process.metadata, "seeded #{process.name} metadata is double-encoded"
    end
  end

  test "operator retries a seeded failed job and it goes back to the ready queue" do
    failed = SolidQueue::FailedExecution.first

    failed.retry

    assert_nil SolidQueue::FailedExecution.find_by(id: failed.id), "retried job is still failed"
    assert SolidQueue::ReadyExecution.exists?(job_id: failed.job_id), "retried job never reached the ready queue"
  end

  test "operator retries all seeded failed jobs from the dashboard" do
    failed_job_ids = SolidQueue::FailedExecution.pluck(:job_id)
    assert_not_empty failed_job_ids

    post "/job_harbor/jobs/retry_all", params: { status: "failed" }
    follow_redirect!

    assert_response :success
    assert_equal 0, SolidQueue::FailedExecution.count, "failed jobs remain after retry all"
    assert_equal failed_job_ids.sort, SolidQueue::ReadyExecution.where(job_id: failed_job_ids).pluck(:job_id).sort,
      "retried jobs never reached the ready queue"
    assert_equal "#{failed_job_ids.size} jobs queued for retry.", flash[:notice], "operator saw no confirmation after retry all"
  end
end
