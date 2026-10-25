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
    assert_raises(JobFailure) { claim_job(job, worker: worker).perform }
    job.reload
  end

  # At least one job in every state, across four queues.
  def enqueue_job_in_every_state(worker:)
    enqueue_job(ReportJob, "weekly")
    enqueue_job(ReportJob, "monthly")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(ThrottledImportJob, "acme", queue: "imports")
    enqueue_job(NewsletterJob, "digest", queue: "mailers", at: 2.hours.from_now)
    running = enqueue_job(ReportJob, "quarterly", queue: "critical")
    claim_job(running, worker: worker)
    failed = fail_job(enqueue_job(FlakyPaymentJob, 42, queue: "critical"), worker: worker)
    2.times { |i| finish_job(enqueue_job(ReportJob, "daily-#{i}"), worker: worker) }
    { running: running, failed: failed }
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
