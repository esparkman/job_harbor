# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class ThemeToggleComponentTest < ViewComponentTestCase
    test "renders theme toggle button" do
      render_inline(ThemeToggleComponent.new)

      assert_includes @rendered, "sqd-theme-toggle"
      assert_includes @rendered, "sqd-theme-icon-sun"
      assert_includes @rendered, "sqd-theme-icon-moon"
    end

    test "has correct aria label" do
      render_inline(ThemeToggleComponent.new)

      assert_includes @rendered, 'aria-label="Toggle theme"'
    end

    test "has data-action attribute for JS toggle" do
      render_inline(ThemeToggleComponent.new)

      # HTML entity encodes > as &gt;
      assert_includes @rendered, "data-action="
      assert_includes @rendered, "theme-toggle#toggle"
    end
  end
end
