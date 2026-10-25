class BrokenExportJob < ApplicationJob
  def perform(*)
    raise JobFailure, "Export crashed"
  end
end
