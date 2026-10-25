# frozen_string_literal: true

require "test_helper"

module JobHarbor
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

    test "select carries the class the inline refresh script binds to, with no leftover Stimulus action" do
      render_inline(RefreshSelectorComponent.new)

      assert_includes @rendered, "sqd-refresh-select"
      refute_includes @rendered, "data-action"
    end

    test "operator sees the given default interval as the only chosen refresh option" do
      render_inline(RefreshSelectorComponent.new(default_interval: 30))

      selected = Nokogiri::HTML.fragment(@rendered).css("select.sqd-refresh-select option[selected]")
      assert_equal [ [ "30s", "30" ] ], selected.map { |option| [ option.text, option["value"] ] },
        "The refresh dropdown should show 30s and only 30s as chosen"
    end
  end
end
