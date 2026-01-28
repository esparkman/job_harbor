# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class NavLinkComponentTest < ViewComponentTestCase
    test "renders nav link with label" do
      render_inline(NavLinkComponent.new(
        path: "/dashboard",
        label: "Dashboard",
        icon: "dashboard"
      ))

      assert_includes @rendered, "sqd-nav-link"
      assert_includes @rendered, "Dashboard"
      assert_includes @rendered, "/dashboard"
    end

    test "marks link as active when specified" do
      render_inline(NavLinkComponent.new(
        path: "/jobs",
        label: "Jobs",
        icon: "jobs",
        active: true
      ))

      assert_includes @rendered, "active"
    end

    test "renders badge when provided" do
      render_inline(NavLinkComponent.new(
        path: "/workers",
        label: "Workers",
        icon: "workers",
        badge: 5
      ))

      assert_includes @rendered, "sqd-nav-badge"
      assert_includes @rendered, ">5<"
    end

    test "does not render badge when nil" do
      render_inline(NavLinkComponent.new(
        path: "/workers",
        label: "Workers",
        icon: "workers"
      ))

      refute_includes @rendered, "sqd-nav-badge"
    end

    test "does not render badge when zero" do
      render_inline(NavLinkComponent.new(
        path: "/workers",
        label: "Workers",
        icon: "workers",
        badge: 0
      ))

      refute_includes @rendered, "sqd-nav-badge"
    end
  end
end
