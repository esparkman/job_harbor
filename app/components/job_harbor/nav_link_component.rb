# frozen_string_literal: true

module JobHarbor
  class NavLinkComponent < ApplicationComponent
    def initialize(path:, label:, icon:, active: false, badge: nil)
      @path = path
      @label = label
      @icon = icon.to_sym
      @active = active
      @badge = badge
    end

    def call
      link_to @path, class: css_classes do
        safe_join([
          content_tag(:span, @label),
          badge_tag
        ].compact)
      end
    end

    private

    def css_classes
      classes = [ "sqd-nav-link", "navbar-item" ]
      classes << "active navbar-item-current" if @active
      classes.join(" ")
    end

    def badge_tag
      return nil unless @badge.present? && @badge.to_i > 0

      content_tag(:span, @badge, class: "sqd-nav-badge navbar-badge")
    end
  end
end
