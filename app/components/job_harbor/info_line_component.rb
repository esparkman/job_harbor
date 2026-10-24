# frozen_string_literal: true

module JobHarbor
  class InfoLineComponent < ApplicationComponent
    def initialize(label:, value: nil)
      @label = label
      @value = value
    end

    def call
      content_tag(:div, class: "info-line") do
        safe_join([
          content_tag(:span, @label, class: "info-line-label"),
          content_tag(:span, "", class: "info-line-separator"),
          content_tag(:span, content? ? content : @value, class: "info-line-value")
        ])
      end
    end
  end
end
