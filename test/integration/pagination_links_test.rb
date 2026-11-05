require "test_helper"

class PaginationLinksTest < ActionDispatch::IntegrationTest
  test "operator pages through a filtered status tab and page 2 keeps the tab and the filters" do
    30.times { |i| enqueue_job(ReportJob, "report-#{i}") }
    5.times { |i| enqueue_job(NewsletterJob, "digest-#{i}") }

    get "/job_harbor/jobs/status/pending", params: { class_name: "ReportJob" }
    get css_select(".pagination-link").find { |a| a.text.strip == "2" }["href"]

    assert_response :success
    assert_select "h1", text: "Pending Jobs"
    assert_equal 5, css_select("table.sqd-table tbody tr").size, "Page 2 of 30 ReportJobs should hold the last 5"
    assert_equal [ "ReportJob" ], css_select("table.sqd-table tbody tr code").map { |c| c.text.strip }.uniq,
      "Page 2 dropped the class filter"
  end

  test "operator pages through search results and page 2 is still the same search" do
    30.times { |i| enqueue_job(ReportJob, "report-#{i}") }
    enqueue_job(NewsletterJob, "digest")

    get "/job_harbor/search", params: { q: "ReportJob" }
    next_href = css_select("a.pagination-link").find { |a| a.text.include?("Next") }["href"]
    get next_href

    assert_response :success
    assert_select "h1", text: "Search Results"
    assert_equal 5, css_select("table.sqd-table tbody tr").size
  end

  test "page links keep the chosen page size and replace the current page" do
    30.times { |i| enqueue_job(ReportJob, "report-#{i}") }

    get "/job_harbor/jobs/status/pending", params: { per_page: 10, page: 2 }

    hrefs = css_select("a.pagination-link").map { |a| a["href"] }
    assert_includes hrefs, "/job_harbor/jobs/status/pending?page=3&per_page=10"
    assert hrefs.none? { |href| href.scan("page=").size > 2 }, "A page link repeated the page parameter: #{hrefs.inspect}"
  end
end
