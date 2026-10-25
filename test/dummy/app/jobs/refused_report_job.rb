class RefusedReportJob < ReportJob
  before_enqueue { throw :abort }
end
