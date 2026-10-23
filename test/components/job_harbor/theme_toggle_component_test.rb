# frozen_string_literal: true

require "test_helper"

module JobHarbor
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

    test "is a button the inline theme script can find, with no leftover Stimulus action" do
      render_inline(ThemeToggleComponent.new)

      assert_includes @rendered, '<button class="sqd-theme-toggle'
      assert_includes @rendered, 'type="button"'
      refute_includes @rendered, "data-action"
    end
  end
end
