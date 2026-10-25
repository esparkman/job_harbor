# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class PerPageSelectorComponentTest < ViewComponentTestCase
    test "renders per-page selector with label" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_includes @rendered, "sqd-per-page-selector"
      assert_includes @rendered, "Show"
    end

    test "select carries the class the inline script binds to, with no leftover Stimulus action or inline style" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_includes @rendered, "sqd-per-page-select"
      refute_includes @rendered, "data-action"
      refute_includes @rendered, "style="
    end

    test "includes all page size options" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_includes @rendered, ">10<"
      assert_includes @rendered, ">25<"
      assert_includes @rendered, ">50<"
      assert_includes @rendered, ">100<"
    end

    test "operator sees the current page size as the only chosen option" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 50, current_path: "/jobs"))

      assert_equal [ "50" ], options.select { |option| option["selected"] }.map(&:text),
        "The page size dropdown should show 50 and only 50 as chosen"
    end

    test "each page size links back to /jobs with that per_page" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_equal %w[/jobs?per_page=10 /jobs?per_page=25 /jobs?per_page=50 /jobs?per_page=100],
        options.map { |option| option["value"] }
    end

    test "changing page size keeps the operator's other filters" do
      render_inline(PerPageSelectorComponent.new(
        current_per_page: 25,
        current_path: "/jobs",
        params: { status: "failed" }
      ))

      assert_equal %w[10 25 50 100].map { |size| "/jobs?per_page=#{size}&status=failed" },
        options.map { |option| option["value"] }
    end

    test "changing page size sends the operator back to page 1" do
      render_inline(PerPageSelectorComponent.new(
        current_per_page: 25,
        current_path: "/jobs",
        params: { page: 3, status: "failed" }
      ))

      queries = options.map { |option| Rack::Utils.parse_query(URI.parse(option["value"]).query) }

      assert_equal 4, queries.size
      queries.each do |query|
        refute query.key?("page"), "Picking a new page size should land on page 1, got #{query.inspect}"
        assert_equal "failed", query["status"], "Picking a new page size should keep the status filter"
      end
    end

    private

    def options
      Nokogiri::HTML.fragment(@rendered).css("select.sqd-per-page-select option")
    end
  end
end
