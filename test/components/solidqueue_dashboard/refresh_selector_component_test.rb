# frozen_string_literal: true

require "test_helper"

module SolidqueueDashboard
  class RefreshSelectorComponentTest < ViewComponentTestCase
    test "renders refresh selector with dropdown" do
      render_inline(RefreshSelectorComponent.new)

      assert_includes @rendered, "sqd-refresh-selector"
      assert_includes @rendered, "select"
    end

    test "includes all interval options" do
      render_inline(RefreshSelectorComponent.new)

      assert_includes @rendered, "Off"
      assert_includes @rendered, "15s"
      assert_includes @rendered, "30s"
      assert_includes @rendered, "1m"
      assert_includes @rendered, "5m"
    end

    test "has data-action attribute for change handler" do
      render_inline(RefreshSelectorComponent.new)

      assert_includes @rendered, "data-action="
      assert_includes @rendered, "change"
    end

    test "accepts default_interval parameter" do
      render_inline(RefreshSelectorComponent.new(default_interval: 30))

      assert_includes @rendered, "sqd-refresh-selector"
    end
  end
end
