# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobFiltersComponentTest < ViewComponentTestCase
    test "renders the class and queue filter dropdowns" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob", "OtherJob" ],
        queue_names: [ "default", "high" ],
        current_class: nil,
        current_queue: nil,
        current_path: "/jobs"
      ))

      filters = Nokogiri::HTML.fragment(@rendered).at_css("div.sqd-filters")
      assert filters, "Filter bar should render"
      assert filters.at_css("select#class_filter"), "Class filter dropdown should render"
      assert filters.at_css("select#queue_filter"), "Queue filter dropdown should render"
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

      assert_equal [ "All Classes", "TestJob", "OtherJob" ],
        Nokogiri::HTML.fragment(@rendered).css("#class_filter option").map(&:text)
    end

    test "includes all queue name options" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob" ],
        queue_names: [ "default", "high" ],
        current_class: nil,
        current_queue: nil,
        current_path: "/jobs"
      ))

      assert_equal [ "All Queues", "default", "high" ],
        Nokogiri::HTML.fragment(@rendered).css("#queue_filter option").map(&:text)
    end

    test "operator sees the active class and queue filters as the chosen options, and no others" do
      render_inline(JobFiltersComponent.new(
        class_names: [ "TestJob", "OtherJob" ],
        queue_names: [ "default", "high" ],
        current_class: "TestJob",
        current_queue: "high",
        current_path: "/jobs"
      ))

      doc = Nokogiri::HTML.fragment(@rendered)
      assert_equal [ "TestJob" ], doc.css("#class_filter option[selected]").map(&:text),
        "Class dropdown should show the active class filter and nothing else"
      assert_equal [ "high" ], doc.css("#queue_filter option[selected]").map(&:text),
        "Queue dropdown should show the active queue filter and nothing else"
    end
  end
end
