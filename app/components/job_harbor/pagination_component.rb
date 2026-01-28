# frozen_string_literal: true

module JobHarbor
  class PaginationComponent < ApplicationComponent
    def initialize(pagy:)
      @pagy = pagy
    end

    def render?
      @pagy.pages > 1
    end

    def call
      content_tag(:nav, class: "sqd-pagination") do
        safe_join([
          prev_link,
          page_links,
          next_link
        ])
      end
    end

    private

    def prev_link
      if @pagy.prev
        link_to "← Prev", url_for(page: @pagy.prev), class: "sqd-pagination-link"
      else
        content_tag(:span, "← Prev", class: "sqd-pagination-link sqd-pagination-disabled")
      end
    end

    def next_link
      if @pagy.next
        link_to "Next →", url_for(page: @pagy.next), class: "sqd-pagination-link"
      else
        content_tag(:span, "Next →", class: "sqd-pagination-link sqd-pagination-disabled")
      end
    end

    def page_links
      series.map do |item|
        case item
        when Integer
          if item == @pagy.page
            content_tag(:span, item, class: "sqd-pagination-current")
          else
            link_to item, url_for(page: item), class: "sqd-pagination-link"
          end
        when :gap
          content_tag(:span, "…", class: "sqd-pagination-link sqd-pagination-disabled")
        end
      end
    end

    def series
      # Generate page series with ellipsis for large page counts
      pages = @pagy.pages
      current = @pagy.page

      if pages <= 7
        (1..pages).to_a
      elsif current <= 4
        [ 1, 2, 3, 4, 5, :gap, pages ]
      elsif current >= pages - 3
        [ 1, :gap, pages - 4, pages - 3, pages - 2, pages - 1, pages ]
      else
        [ 1, :gap, current - 1, current, current + 1, :gap, pages ]
      end
    end
  end
end
