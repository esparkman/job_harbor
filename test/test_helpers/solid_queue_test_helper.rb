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
    assert_raises(FlakyPaymentJob::GatewayError) { claim_job(job, worker: worker).perform }
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
