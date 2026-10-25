# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class NavLinkComponentTest < ViewComponentTestCase
    test "renders nav link with label" do
      render_inline(NavLinkComponent.new(
        path: "/dashboard",
        label: "Dashboard"
      ))

      assert_includes @rendered, "sqd-nav-link"
      assert_includes @rendered, "Dashboard"
      assert_equal "/dashboard", Nokogiri::HTML.fragment(@rendered).at_css("a.sqd-nav-link")["href"]
    end

    test "the current section's link is highlighted and other links are not" do
      render_inline(NavLinkComponent.new(path: "/jobs", label: "Jobs", active: true))
      active_classes = Nokogiri::HTML.fragment(@rendered).at_css("a[href='/jobs']")["class"].split

      render_inline(NavLinkComponent.new(path: "/queues", label: "Queues"))
      inactive_classes = Nokogiri::HTML.fragment(@rendered).at_css("a[href='/queues']")["class"].split

      assert_includes active_classes, "active"
      assert_includes active_classes, "navbar-item-current"
      refute_includes inactive_classes, "active"
      refute_includes inactive_classes, "navbar-item-current"
    end

    test "renders badge when provided" do
      render_inline(NavLinkComponent.new(
        path: "/workers",
        label: "Workers",
        badge: 5
      ))

      assert_includes @rendered, "sqd-nav-badge"
      assert_includes @rendered, ">5<"
    end

    test "does not render badge when nil" do
      render_inline(NavLinkComponent.new(
        path: "/workers",
        label: "Workers"
      ))

      refute_includes @rendered, "sqd-nav-badge"
    end

    test "does not render badge when zero" do
      render_inline(NavLinkComponent.new(
        path: "/workers",
        label: "Workers",
        badge: 0
      ))

      refute_includes @rendered, "sqd-nav-badge"
    end
  end
end
