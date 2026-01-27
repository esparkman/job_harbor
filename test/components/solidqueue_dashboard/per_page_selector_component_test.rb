# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class PerPageSelectorComponentTest < ViewComponentTestCase
    test "renders per-page selector with label" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_includes @rendered, "sqd-per-page-selector"
      assert_includes @rendered, "Show"
    end

    test "includes all page size options" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_includes @rendered, ">10<"
      assert_includes @rendered, ">25<"
      assert_includes @rendered, ">50<"
      assert_includes @rendered, ">100<"
    end

    test "marks current per_page as selected" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 50, current_path: "/jobs"))

      # The selected option should be marked
      assert_includes @rendered, "selected"
    end

    test "generates correct links with per_page parameter" do
      render_inline(PerPageSelectorComponent.new(current_per_page: 25, current_path: "/jobs"))

      assert_includes @rendered, "per_page="
    end

    test "preserves existing query parameters" do
      render_inline(PerPageSelectorComponent.new(
        current_per_page: 25,
        current_path: "/jobs",
        params: { status: "failed" }
      ))

      assert_includes @rendered, "status=failed"
    end
  end
end
