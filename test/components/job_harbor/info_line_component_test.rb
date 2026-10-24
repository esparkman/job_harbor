# frozen_string_literal: true

require "test_helper"

module JobHarbor
  class InfoLineComponentTest < ViewComponentTestCase
    test "an info line shows its label and value" do
      render_inline(InfoLineComponent.new(label: "Priority", value: "Default"))

      assert_includes @rendered, '<div class="info-line">'
      assert_includes @rendered, '<span class="info-line-label">Priority</span>'
      assert_includes @rendered, '<span class="info-line-separator"></span>'
      assert_includes @rendered, '<span class="info-line-value">Default</span>'
    end

    test "an info line shows a numeric value such as a PID, including zero" do
      render_inline(InfoLineComponent.new(label: "PID", value: 0))

      assert_includes @rendered, '<span class="info-line-value">0</span>'
    end

    test "an info line shows rich block content in place of a plain value" do
      render_inline(InfoLineComponent.new(label: "Job Class")
        .with_content('<code class="text-sm font-mono">ReportJob</code>'.html_safe))

      assert_includes @rendered, '<span class="info-line-label">Job Class</span>'
      assert_includes @rendered,
        '<span class="info-line-value"><code class="text-sm font-mono">ReportJob</code></span>'
    end

    test "an info line shows block content when a value is also given" do
      render_inline(InfoLineComponent.new(label: "Job Class", value: "Plain")
        .with_content("Block".html_safe))

      assert_includes @rendered, '<span class="info-line-value">Block</span>'
      refute_includes @rendered, "Plain"

      render_inline(InfoLineComponent.new(label: "Job Class", value: "")
        .with_content("Block".html_safe))

      assert_includes @rendered, '<span class="info-line-value">Block</span>'
    end

    test "an info line escapes unsafe block content" do
      render_inline(InfoLineComponent.new(label: "Worker").with_content("<i>x</i>"))

      assert_includes @rendered, "&lt;i&gt;"
      refute_includes @rendered, "<i>"
    end

    test "an info line escapes a plain value so job data cannot inject markup" do
      render_inline(InfoLineComponent.new(label: "Worker", value: "<script>alert(1)</script>"))

      assert_includes @rendered, "&lt;script&gt;alert(1)&lt;/script&gt;"
      refute_includes @rendered, "<script>"
    end

    test "an info line escapes its label" do
      render_inline(InfoLineComponent.new(label: "<b>Label</b>", value: "x"))

      assert_includes @rendered, "&lt;b&gt;Label&lt;/b&gt;"
      refute_includes @rendered, "<b>"
    end

    test "an info line with label only still shows its label" do
      render_inline(InfoLineComponent.new(label: "Hostname"))

      assert_includes @rendered, '<span class="info-line-label">Hostname</span>'
      assert_includes @rendered, '<span class="info-line-value"></span>'
    end
  end
end
