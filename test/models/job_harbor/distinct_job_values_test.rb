# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class DistinctJobValuesTest < ActiveSupport::TestCase
    include SolidQueueTestHelper

    setup do
      @worker = register_worker(name: "worker-1")
      %w[mailers reports default critical].each_with_index do |queue, index|
        (index + 1).times { enqueue_job(ReportJob, queue: queue) }
      end
      enqueue_job(NewsletterJob, queue: "mailers")
      finish_job(enqueue_job(ReportJob, queue: "billing.charges"), worker: @worker)
    end

    test "queue names match what a plain distinct lookup returns" do
      assert_equal SolidQueue::Job.distinct.pluck(:queue_name).sort, DistinctJobValues.of(:queue_name)
    end

    test "class names match what a plain distinct lookup returns" do
      assert_equal SolidQueue::Job.distinct.pluck(:class_name).sort, DistinctJobValues.of(:class_name)
    end

    test "values come back sorted with no duplicates" do
      names = DistinctJobValues.of(:queue_name)

      assert_equal %w[billing.charges critical default mailers reports], names
    end

    test "names sort in byte order, uppercase before lowercase" do
      SolidQueue::Job.delete_all
      %w[alpha Zeta].each { |queue| enqueue_job(ReportJob, queue: queue) }

      assert_equal %w[Zeta alpha], DistinctJobValues.of(:queue_name)
    end

    test "more than a thousand distinct names all come back" do
      now = Time.current
      SolidQueue::Job.insert_all(1_100.times.map { |n|
        { queue_name: format("bulk_%04d", n), class_name: "ReportJob", arguments: "{}", created_at: now, updated_at: now }
      })

      names = DistinctJobValues.of(:queue_name)

      assert_equal SolidQueue::Job.distinct.pluck(:queue_name).sort, names
      assert_operator names.size, :>, 1_000
    end

    test "no jobs gives an empty list" do
      SolidQueue::Job.delete_all

      assert_equal [], DistinctJobValues.of(:queue_name)
    end

    test "only the filterable columns are accepted" do
      assert_raises(ArgumentError) { DistinctJobValues.of(:arguments) }
    end
  end
end
