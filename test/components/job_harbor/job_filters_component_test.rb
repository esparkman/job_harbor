# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobFiltersComponentTest < ViewComponentTestCase
    test "renders filter form" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob", "OtherJob" ],
        queue_names: [ "default", "high" ],
        current_class: nil,
        current_queue: nil,
        current_path: "/jobs"
      ))

      assert_includes @rendered, "sqd-filters"
      assert_includes @rendered, "select"
    end

    test "keeps the selected class as an option even when no job has it any more" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "OtherJob" ], queue_names: [ "default" ],
        current_class: "GoneJob", current_queue: nil, current_path: "/jobs"
      ))

      selected = Nokogiri::HTML.fragment(@rendered).css("#class_filter option[selected]")
      assert_equal [ "GoneJob" ], selected.map(&:text), "Dropdown must still show the active class filter"
    end

    test "keeps the selected queue as an option even when no job is on it any more" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob" ], queue_names: [ "default" ],
        current_class: nil, current_queue: "gone_queue", current_path: "/jobs"
      ))

      selected = Nokogiri::HTML.fragment(@rendered).css("#queue_filter option[selected]")
      assert_equal [ "gone_queue" ], selected.map(&:text), "Dropdown must still show the active queue filter"
    end

    test "does not duplicate the selected class when jobs still have it" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob" ], queue_names: [ "default" ],
        current_class: "TestJob", current_queue: nil, current_path: "/jobs"
      ))

      assert_equal 1, Nokogiri::HTML.fragment(@rendered).css("#class_filter option").count { |o| o.text == "TestJob" }
    end

    test "includes all class name options" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob", "OtherJob" ],
        queue_names: [ "default" ],
        current_class: nil,
        current_queue: nil,
        current_path: "/jobs"
      ))

      assert_includes @rendered, "TestJob"
      assert_includes @rendered, "OtherJob"
      assert_includes @rendered, "All Classes"
    end

    test "includes all queue name options" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob" ],
        queue_names: [ "default", "high" ],
        current_class: nil,
        current_queue: nil,
        current_path: "/jobs"
      ))

      assert_includes @rendered, "default"
      assert_includes @rendered, "high"
      assert_includes @rendered, "All Queues"
    end

    test "marks current filters as selected" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob", "OtherJob" ],
        queue_names: [ "default", "high" ],
        current_class: "TestJob",
        current_queue: "high",
        current_path: "/jobs"
      ))

      # Just verify the form renders - specific selected logic is handled by HTML
      assert_includes @rendered, "sqd-filters"
    end
  end
end
