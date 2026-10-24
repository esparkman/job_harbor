# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class JobSearchFormComponentTest < ViewComponentTestCase
    test "operator sees an empty search box that submits to job search" do
      render_inline(JobSearchFormComponent.new)

      form = Nokogiri::HTML.fragment(@rendered).at_css("form")
      assert_equal "get", form["method"]
      assert_equal search_path, form["action"]

      input = form.at_css("input[name=q]")
      assert_equal "Search jobs...", input["placeholder"]
      assert_nil input["value"]
      assert_includes @rendered, 'value="Search"'
    end

    test "search box is prefilled with the current query" do
      render_inline(JobSearchFormComponent.new(query: "ReportJob"))

      assert_equal "ReportJob", Nokogiri::HTML.fragment(@rendered).at_css("input[name=q]")["value"]
    end

    test "current query is escaped in the search box" do
      render_inline(JobSearchFormComponent.new(query: %("><script>alert(1)</script>)))

      refute_includes @rendered, "<script>"
      assert_includes @rendered, "&quot;&gt;&lt;script&gt;"
    end
  end
end
