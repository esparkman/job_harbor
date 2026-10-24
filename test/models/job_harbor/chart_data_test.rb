# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class ChartDataTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup { freeze_time }

    test "available_ranges lists every range with its label" do
      assert_equal %w[15m 1h 6h 24h 7d], ChartData.available_ranges.map { |r| r[:value] }
      assert_equal "24 hours", ChartData.available_ranges.find { |r| r[:value] == "24h" }[:label]
    end

    test "every range returns one label and one count per bucket" do
      expected = { "15m" => 15, "1h" => 12, "6h" => 12, "24h" => 24, "7d" => 28 }

      expected.each do |range, buckets|
        series = ChartData.new(range: range).series

        assert_equal buckets, series[:labels].size, "#{range} should have #{buckets} labels"
        %i[completed failed enqueued].each do |name|
          assert_equal buckets, series[name].size, "#{range} #{name} counts should match its labels"
        end
      end
    end

    test "an unknown range falls back to 24h" do
      assert_equal 24, ChartData.new(range: "nope").series[:labels].size
    end

    test "labels are clock times up to a day and dates beyond" do
      assert_match(/\A\d\d:\d\d\z/, ChartData.new(range: "24h").series[:labels].first)
      assert_match(/\A[A-Z][a-z]{2} \d\d\z/, ChartData.new(range: "7d").series[:labels].first)
    end

    test "enqueued jobs land in the bucket for their enqueue time" do
      # 24h buckets are an hour wide and start 24 hours ago: bucket 4 is 20h to 19h ago, bucket 23 is the last hour.
      enqueue_job(ReportJob, "mid").update_columns(created_at: 19.hours.ago - 30.minutes)
      enqueue_job(ReportJob, "recent").update_columns(created_at: 5.minutes.ago)
      enqueue_job(ReportJob, "too old").update_columns(created_at: 2.days.ago)

      series = ChartData.new(range: "24h").series

      assert_equal 1, series[:enqueued][4], "A job enqueued 19.5h ago belongs in bucket 4"
      assert_equal 1, series[:enqueued][23], "A job enqueued 5 minutes ago belongs in the last bucket"
      assert_equal 2, series[:enqueued].sum, "A job enqueued before the window must not be counted"
    end

    test "completed jobs land in the bucket for their finish time" do
      worker = register_worker(name: "w")
      finish_job(enqueue_job(ReportJob, "done"), worker: worker).update_columns(finished_at: 3.hours.ago + 1.minute)
      enqueue_job(ReportJob, "unfinished")

      series = ChartData.new(range: "24h").series

      assert_equal 1, series[:completed][21], "A job finished 2h59m ago belongs in bucket 21"
      assert_equal 1, series[:completed].sum, "Only finished jobs count as completed"
    end

    test "failed counts use the failure time, not the job's enqueue time" do
      worker = register_worker(name: "w")
      job = fail_job(enqueue_job(FlakyPaymentJob, 1), worker: worker)
      job.failed_execution.update_columns(created_at: 2.hours.ago + 5.minutes)

      series = ChartData.new(range: "24h").series

      assert_equal 1, series[:failed][22]
      assert_equal 1, series[:failed].sum
    end

    test "the 7d range puts jobs from different days in their own 6 hour buckets" do
      # 7d buckets are 6 hours wide from 7 days ago: bucket 0 is the first 6 hours, bucket 27 the last.
      { 6.days.ago + 1.hour => 3, 3.days.ago + 7.hours => 4, 2.hours.ago => 2 }.each do |time, count|
        count.times { |i| enqueue_job(ReportJob, "#{time.to_i}-#{i}").update_columns(created_at: time) }
      end
      enqueue_job(ReportJob, "too old").update_columns(created_at: 8.days.ago)

      enqueued = ChartData.new(range: "7d").series[:enqueued]

      assert_equal 3, enqueued[4], "Three jobs from 6 days ago belong in bucket 4"
      assert_equal 4, enqueued[17], "Four jobs from 3 days ago belong in bucket 16"
      assert_equal 2, enqueued[27], "Two jobs from 2 hours ago belong in the last bucket"
      assert_equal 9, enqueued.sum
    end

    test "a job enqueued at the instant the chart is built is counted in the last bucket" do
      enqueue_job(ReportJob, "now")

      assert_equal 1, ChartData.new(range: "15m").series[:enqueued].last
    end

    test "the 24h range runs one query per series however many jobs there are" do
      worker = register_worker(name: "w")
      40.times { |i| enqueue_job(ReportJob, i) }
      3.times { |i| finish_job(enqueue_job(ReportJob, "f#{i}"), worker: worker) }
      fail_job(enqueue_job(FlakyPaymentJob, 1), worker: worker)

      queries = count_queries { ChartData.new(range: "24h").series }

      assert_equal 3, queries.size, "The chart should issue one query per series, got:\n#{queries.join("\n")}"
    end
  end
end
