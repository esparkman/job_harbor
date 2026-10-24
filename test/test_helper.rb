# Serialize runs: they share one SQLite file and reload the SQ schema on boot.
require "fileutils"
FileUtils.mkdir_p(File.expand_path("dummy/tmp", __dir__))
TEST_SUITE_LOCK = File.open(File.expand_path("dummy/tmp/test-suite.lock", __dir__), File::RDWR | File::CREAT)
unless TEST_SUITE_LOCK.flock(File::LOCK_EX | File::LOCK_NB)
  $stderr.puts "Waiting for another test run to finish (lock: #{TEST_SUITE_LOCK.path})…"
  TEST_SUITE_LOCK.flock(File::LOCK_EX)
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
require "rails/test_help"
require "view_component/test_helpers"

# Load after rails/test_help so maintain_test_schema! can't wipe these tables.
module SolidQueueTestSchema
  PATH = File.join(Gem.loaded_specs["solid_queue"].full_gem_path,
    "lib/generators/solid_queue/install/templates/db/queue_schema.rb")

  def self.load!
    unless SolidQueue::Record.connection_pool.equal?(ActiveRecord::Base.connection_pool)
      raise "SolidQueue::Record has its own connects_to database; load #{PATH} into that database instead"
    end

    ActiveRecord::Migration.suppress_messages { load PATH }
  end
end

SolidQueueTestSchema.load!

class PaymentGatewayError < StandardError; end

class ReportJob < ActiveJob::Base
  # Recurring tasks only record a RecurringExecution when the job runs on Solid Queue.
  self.queue_adapter = :solid_queue

  def perform(*) = nil
end

class NewsletterJob < ActiveJob::Base
  def perform(*) = nil
end

class FlakyPaymentJob < ActiveJob::Base
  def perform(order_id)
    raise PaymentGatewayError, "Card declined for order #{order_id}"
  end
end

class ThrottledImportJob < ActiveJob::Base
  limits_concurrency key: ->(account) { account }

  def perform(*) = nil
end

module SolidQueueTestHelper
  def enqueue_job(job_class, *arguments, queue: "default", at: Time.current)
    active_job = job_class.new(*arguments)
    active_job.queue_name = queue
    SolidQueue::Job.enqueue(active_job, scheduled_at: at)
  end

  # Registers a process the way Solid Queue does: a worker records the queues it polls
  # in metadata as a comma-joined string.
  def register_worker(name:, hostname: "harbor-1", pid: 4242, heartbeat_at: Time.current, kind: "Worker", queues: nil)
    metadata = queues ? { queues: queues } : {}
    SolidQueue::Process.create!(kind: kind, name: name, hostname: hostname, pid: pid,
      last_heartbeat_at: heartbeat_at, metadata: metadata)
  end

  def claim_job(job, worker:)
    SolidQueue::ClaimedExecution.claiming([ job.id ], worker.id) do
      SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
    end.first
  end

  def finish_job(job, worker:)
    claim_job(job, worker: worker).perform
    job.reload
  end

  def fail_job(job, worker:)
    assert_raises(PaymentGatewayError) { claim_job(job, worker: worker).perform }
    job.reload
  end

  def assert_stat_card(label, value)
    card = css_select(".stat-card").find { |c| c.at_css(".stat-card-label").text.strip == label }
    assert card, "Operator expected a '#{label}' stat card but the page has none"
    assert_equal value.to_s, card.at_css(".stat-card-value").text.strip, "'#{label}' stat card shows the wrong number"
  end

  # Statements that reached the database: no schema lookups, transaction control or query-cache hits.
  def count_queries(&block)
    queries = []
    counter = lambda do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached] || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries
  end
end

class ActionDispatch::IntegrationTest
  include SolidQueueTestHelper
end

# ViewComponent test support
class ViewComponentTestCase < ActiveSupport::TestCase
  include ViewComponent::TestHelpers
  include JobHarbor::Engine.routes.url_helpers

  def render_inline(component)
    controller = JobHarbor::ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    @rendered = component.render_in(controller.view_context)
  end
end
