# frozen_string_literal: true

module JobHarbor
  PageInfo = Data.define(:page, :per_page, :count) do
    def pages = (count.to_f / per_page).ceil
    def prev = (page - 1 if page > 1)
    def next = (page + 1 if page < pages)
  end
end
