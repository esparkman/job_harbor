# frozen_string_literal: true

# Seeds for Job Harbor Dashboard demo data
#
# Creates realistic SolidQueue records across all tables to populate
# the dashboard with diverse sample data suitable for screenshots.
#
# Run with: bin/rails db:seed
# Idempotent: safe to run multiple times.

puts "--- Job Harbor: Seeding dashboard demo data ---"
puts ""

module DummySeeds
  module_function

  def job_classes
    {
      "UserNotificationJob" => { queue: "default", priority: 0 },
      "OrderProcessingJob" => { queue: "critical", priority: 1 },
      "ReportGenerationJob" => { queue: "reports", priority: 5 },
      "DataSyncJob" => { queue: "default", priority: 3 },
      "EmailDeliveryJob" => { queue: "mailers", priority: 0 },
      "ImageResizeJob" => { queue: "default", priority: 5 },
      "InventoryCheckJob" => { queue: "critical", priority: 2 },
      "PaymentProcessingJob" => { queue: "critical", priority: 1 },
      "SearchIndexJob" => { queue: "low_priority", priority: 8 },
      "CleanupJob" => { queue: "low_priority", priority: 10 }
    }
  end

  def sample_args
    {
      "UserNotificationJob" => -> { [ { "user_id" => rand(1000..9999), "type" => %w[welcome reminder digest].sample } ] },
      "OrderProcessingJob" => -> { [ { "order_id" => rand(10_000..99_999), "action" => %w[fulfill refund cancel].sample } ] },
      "ReportGenerationJob" => -> { [ { "report_type" => %w[daily weekly monthly quarterly].sample, "format" => %w[pdf csv xlsx].sample } ] },
      "DataSyncJob" => -> { [ { "source" => %w[salesforce hubspot stripe shopify].sample, "batch_size" => [ 100, 500, 1000 ].sample } ] },
      "EmailDeliveryJob" => -> { [ { "to" => "user#{rand(100..999)}@example.com", "template" => %w[welcome reset_password invoice receipt].sample } ] },
      "ImageResizeJob" => -> { [ { "image_id" => rand(1000..9999), "dimensions" => %w[thumbnail medium large hero].sample } ] },
      "InventoryCheckJob" => -> { [ { "warehouse_id" => rand(1..12), "sku_prefix" => %w[ELC FRN CLT SPT HME].sample } ] },
      "PaymentProcessingJob" => -> { [ { "payment_id" => "pay_#{SecureRandom.hex(8)}", "amount_cents" => rand(500..50_000) } ] },
      "SearchIndexJob" => -> { [ { "model" => %w[Product User Order Article].sample, "batch_start" => rand(1..10_000) } ] },
      "CleanupJob" => -> { [ { "table" => %w[sessions temp_files old_notifications expired_tokens].sample, "older_than_days" => [ 7, 14, 30, 90 ].sample } ] }
    }
  end

  def realistic_errors
    [
      { exception_class: "ActiveRecord::RecordNotFound", message: "Couldn't find User with 'id'=12345" },
      { exception_class: "Net::OpenTimeout", message: "execution expired" },
      { exception_class: "Redis::ConnectionError", message: "Error connecting to Redis on 127.0.0.1:6379 (Errno::ECONNREFUSED)" },
      { exception_class: "Stripe::InvalidRequestError", message: "No such charge: 'ch_3abc123'; a]similar object exists in live mode" },
      { exception_class: "ActiveRecord::Deadlocked", message: "Mysql2::Error: Deadlock found when trying to get lock; try restarting transaction" },
      { exception_class: "Timeout::Error", message: "execution expired after 30 seconds" },
      { exception_class: "Net::SMTPServerBusy", message: "450 4.1.2 <user@example.com>: Recipient address rejected: Domain not found" },
      { exception_class: "Aws::S3::Errors::NoSuchKey", message: "The specified key does not exist. Key: uploads/images/photo_8832.jpg" }
    ]
  end

  # SolidQueue expects the full ActiveJob payload as the job arguments.
  def active_job_arguments(job_class_name, *args, executions: 1, queue: "default", priority: 0)
    job_id = SecureRandom.uuid
    {
      "job_class" => job_class_name,
      "job_id" => job_id,
      "provider_job_id" => nil,
      "queue_name" => queue,
      "priority" => priority,
      "arguments" => args,
      "executions" => executions,
      "exception_executions" => {},
      "locale" => "en",
      "timezone" => "UTC",
      "enqueued_at" => Time.current.iso8601(6)
    }
  end

  # Bypasses callbacks so no execution row is created automatically.
  def insert_job!(attrs)
    now = Time.current
    defaults = {
      queue_name: "default",
      priority: 0,
      active_job_id: SecureRandom.uuid,
      created_at: now,
      updated_at: now
    }
    row = defaults.merge(attrs)
    # insert type-casts through the model's JSON coder, so hand it the Hash as is.
    SolidQueue::Job.insert(row)
    SolidQueue::Job.where(active_job_id: row[:active_job_id]).pick(:id)
  end

  # FailedExecution serializes error with a JSON coder, so keep it a Hash.
  def error_payload(exception_class:, message:)
    {
      "exception_class" => exception_class,
      "message" => message,
      "backtrace" => [
        "app/jobs/#{exception_class.underscore.tr('/', '_')}_job.rb:42:in `perform'",
        "activejob/lib/active_job/execution.rb:53:in `perform_now'",
        "activejob/lib/active_job/execution.rb:21:in `block in execute'",
        "activesupport/lib/active_support/callbacks.rb:121:in `run_callbacks'",
        "activejob/lib/active_job/execution.rb:19:in `execute'",
        "solid_queue/lib/solid_queue/worker.rb:18:in `perform'"
      ]
    }
  end

  def run
    clear
    workers = seed_processes
    seed_finished_jobs
    seed_ready_jobs
    seed_scheduled_jobs
    seed_claimed_jobs(workers)
    seed_failed_jobs
    seed_blocked_jobs
    seed_recurring_tasks
    seed_paused_queue
    print_summary
  end

  def clear
    puts "Clearing existing SolidQueue data..."

    SolidQueue::RecurringExecution.delete_all
    SolidQueue::FailedExecution.delete_all
    SolidQueue::ClaimedExecution.delete_all
    SolidQueue::BlockedExecution.delete_all
    SolidQueue::ScheduledExecution.delete_all
    SolidQueue::ReadyExecution.delete_all
    SolidQueue::Semaphore.delete_all
    SolidQueue::Pause.delete_all
    SolidQueue::Process.delete_all
    SolidQueue::RecurringTask.delete_all
    SolidQueue::Job.delete_all

    puts "  Done."
    puts ""
  end

  # Claimed executions need these, so they are created first.
  def seed_processes
    puts "Creating worker processes..."

    supervisor = SolidQueue::Process.create!(
      kind: "Supervisor",
      last_heartbeat_at: 15.seconds.ago,
      pid: 48_201,
      hostname: "web-prod-01.internal",
      name: "supervisor-web-prod-01-48201",
      metadata: { polling_interval: 0.1 }
    )

    worker_1 = SolidQueue::Process.create!(
      kind: "Worker",
      last_heartbeat_at: 10.seconds.ago,
      supervisor_id: supervisor.id,
      pid: 48_210,
      hostname: "web-prod-01.internal",
      name: "worker-web-prod-01-48210",
      metadata: { queues: "default,mailers,critical", polling_interval: 0.1, thread_count: 5 }
    )

    worker_2 = SolidQueue::Process.create!(
      kind: "Worker",
      last_heartbeat_at: 8.seconds.ago,
      supervisor_id: supervisor.id,
      pid: 48_215,
      hostname: "web-prod-01.internal",
      name: "worker-web-prod-01-48215",
      metadata: { queues: "reports,low_priority", polling_interval: 1, thread_count: 3 }
    )

    worker_3 = SolidQueue::Process.create!(
      kind: "Worker",
      last_heartbeat_at: 22.seconds.ago,
      supervisor_id: supervisor.id,
      pid: 51_003,
      hostname: "worker-prod-02.internal",
      name: "worker-worker-prod-02-51003",
      metadata: { queues: "*", polling_interval: 0.2, thread_count: 5 }
    )

    puts "  Created 1 supervisor + 3 workers."
    puts ""

    [ worker_1, worker_2, worker_3 ]
  end

  def seed_finished_jobs
    puts "Creating finished jobs..."

    28.times do
      class_name = job_classes.keys.sample
      config = job_classes[class_name]
      created = rand(1..23).hours.ago - rand(0..59).minutes
      finished = created + rand(1..120).seconds
      args = active_job_arguments(class_name, *sample_args[class_name].call, queue: config[:queue], priority: config[:priority])

      insert_job!(
        queue_name: config[:queue],
        class_name: class_name,
        arguments: args,
        priority: config[:priority],
        active_job_id: args["job_id"],
        scheduled_at: created,
        finished_at: finished,
        created_at: created,
        updated_at: finished
      )
    end

    puts "  Created #{SolidQueue::Job.where.not(finished_at: nil).count} finished jobs."
    puts ""
  end

  def seed_ready_jobs
    puts "Creating pending (ready) jobs..."

    10.times do
      class_name = job_classes.keys.sample
      config = job_classes[class_name]
      created = rand(30..600).seconds.ago
      args = active_job_arguments(class_name, *sample_args[class_name].call, queue: config[:queue], priority: config[:priority])

      job_id = insert_job!(
        queue_name: config[:queue],
        class_name: class_name,
        arguments: args,
        priority: config[:priority],
        active_job_id: args["job_id"],
        scheduled_at: created,
        created_at: created,
        updated_at: created
      )

      SolidQueue::ReadyExecution.insert({
        job_id: job_id,
        queue_name: config[:queue],
        priority: config[:priority],
        created_at: created
      })
    end

    puts "  Created #{SolidQueue::ReadyExecution.count} pending jobs with ready executions."
    puts ""
  end

  def seed_scheduled_jobs
    puts "Creating scheduled jobs..."

    scheduled_configs = [
      { class_name: "ReportGenerationJob", offset: 2.hours },
      { class_name: "DataSyncJob", offset: 30.minutes },
      { class_name: "CleanupJob", offset: 6.hours },
      { class_name: "EmailDeliveryJob", offset: 15.minutes },
      { class_name: "InventoryCheckJob", offset: 1.hour },
      { class_name: "SearchIndexJob", offset: 45.minutes }
    ]

    scheduled_configs.each do |sc|
      class_name = sc[:class_name]
      config = job_classes[class_name]
      scheduled_at = sc[:offset].from_now
      created = rand(1..10).minutes.ago
      args = active_job_arguments(class_name, *sample_args[class_name].call, queue: config[:queue], priority: config[:priority])

      job_id = insert_job!(
        queue_name: config[:queue],
        class_name: class_name,
        arguments: args,
        priority: config[:priority],
        active_job_id: args["job_id"],
        scheduled_at: scheduled_at,
        created_at: created,
        updated_at: created
      )

      SolidQueue::ScheduledExecution.insert({
        job_id: job_id,
        queue_name: config[:queue],
        priority: config[:priority],
        scheduled_at: scheduled_at,
        created_at: created
      })
    end

    puts "  Created #{SolidQueue::ScheduledExecution.count} scheduled jobs."
    puts ""
  end

  def seed_claimed_jobs(workers)
    puts "Creating in-progress (claimed) jobs..."

    worker_1, worker_2, worker_3 = workers
    claimed_configs = [
      { class_name: "OrderProcessingJob", worker: worker_1, started: 12.seconds.ago },
      { class_name: "PaymentProcessingJob", worker: worker_1, started: 45.seconds.ago },
      { class_name: "ReportGenerationJob", worker: worker_2, started: 3.minutes.ago },
      { class_name: "ImageResizeJob", worker: worker_3, started: 8.seconds.ago }
    ]

    claimed_configs.each do |cc|
      class_name = cc[:class_name]
      config = job_classes[class_name]
      created = cc[:started] - rand(1..5).seconds
      args = active_job_arguments(class_name, *sample_args[class_name].call, queue: config[:queue], priority: config[:priority])

      job_id = insert_job!(
        queue_name: config[:queue],
        class_name: class_name,
        arguments: args,
        priority: config[:priority],
        active_job_id: args["job_id"],
        scheduled_at: created,
        created_at: created,
        updated_at: created
      )

      SolidQueue::ClaimedExecution.insert({
        job_id: job_id,
        process_id: cc[:worker].id,
        created_at: cc[:started]
      })
    end

    puts "  Created #{SolidQueue::ClaimedExecution.count} in-progress jobs."
    puts ""
  end

  def seed_failed_jobs
    puts "Creating failed jobs..."

    failed_configs = [
      { class_name: "OrderProcessingJob", error_idx: 0, ago: 5.minutes.ago, executions: 3 },
      { class_name: "EmailDeliveryJob", error_idx: 6, ago: 18.minutes.ago, executions: 2 },
      { class_name: "PaymentProcessingJob", error_idx: 3, ago: 42.minutes.ago, executions: 1 },
      { class_name: "DataSyncJob", error_idx: 2, ago: 1.hour.ago, executions: 5 },
      { class_name: "ImageResizeJob", error_idx: 7, ago: 2.hours.ago, executions: 3 },
      { class_name: "UserNotificationJob", error_idx: 1, ago: 3.hours.ago, executions: 2 },
      { class_name: "InventoryCheckJob", error_idx: 4, ago: 6.hours.ago, executions: 4 },
      { class_name: "SearchIndexJob", error_idx: 5, ago: 8.hours.ago, executions: 1 }
    ]

    failed_configs.each do |fc|
      class_name = fc[:class_name]
      config = job_classes[class_name]
      error_info = realistic_errors[fc[:error_idx]]
      created = fc[:ago] - rand(60..300).seconds
      failed_at = fc[:ago]
      args = active_job_arguments(
        class_name,
        *sample_args[class_name].call,
        executions: fc[:executions],
        queue: config[:queue],
        priority: config[:priority]
      )

      job_id = insert_job!(
        queue_name: config[:queue],
        class_name: class_name,
        arguments: args,
        priority: config[:priority],
        active_job_id: args["job_id"],
        scheduled_at: created,
        created_at: created,
        updated_at: failed_at
      )

      SolidQueue::FailedExecution.insert({
        job_id: job_id,
        error: error_payload(**error_info),
        created_at: failed_at
      })
    end

    puts "  Created #{SolidQueue::FailedExecution.count} failed jobs."
    puts ""
  end

  def seed_blocked_jobs
    puts "Creating blocked jobs..."

    blocked_configs = [
      { class_name: "PaymentProcessingJob", concurrency_key: "payment_gateway_mutex", expires_in: 5.minutes },
      { class_name: "OrderProcessingJob", concurrency_key: "order_processing/user_4521", expires_in: 10.minutes },
      { class_name: "DataSyncJob", concurrency_key: "salesforce_api_limit", expires_in: 15.minutes }
    ]

    blocked_configs.each do |bc|
      class_name = bc[:class_name]
      config = job_classes[class_name]
      created = rand(30..180).seconds.ago
      args = active_job_arguments(class_name, *sample_args[class_name].call, queue: config[:queue], priority: config[:priority])

      job_id = insert_job!(
        queue_name: config[:queue],
        class_name: class_name,
        arguments: args,
        priority: config[:priority],
        active_job_id: args["job_id"],
        scheduled_at: created,
        concurrency_key: bc[:concurrency_key],
        created_at: created,
        updated_at: created
      )

      SolidQueue::BlockedExecution.insert({
        job_id: job_id,
        queue_name: config[:queue],
        priority: config[:priority],
        concurrency_key: bc[:concurrency_key],
        expires_at: bc[:expires_in].from_now,
        created_at: created
      })

      # value 0 = all slots taken
      SolidQueue::Semaphore.insert({
        key: bc[:concurrency_key],
        value: 0,
        expires_at: bc[:expires_in].from_now,
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    puts "  Created #{SolidQueue::BlockedExecution.count} blocked jobs with semaphores."
    puts ""
  end

  def seed_recurring_tasks
    puts "Creating recurring tasks..."

    recurring_tasks = [
      {
        key: "health_check",
        schedule: "*/5 * * * *",
        class_name: "HealthCheckJob",
        queue_name: "default",
        priority: 0,
        static: true,
        description: "Pings external services and records uptime every 5 minutes"
      },
      {
        key: "hourly_digest",
        schedule: "0 * * * *",
        class_name: "EmailDeliveryJob",
        queue_name: "mailers",
        priority: 0,
        static: true,
        description: "Sends hourly digest emails to subscribed users"
      },
      {
        key: "nightly_cleanup",
        schedule: "0 0 * * *",
        class_name: "CleanupJob",
        queue_name: "low_priority",
        priority: 10,
        static: true,
        description: "Removes expired sessions, temp files, and old notifications at midnight"
      },
      {
        key: "weekly_report",
        schedule: "0 9 * * 1",
        class_name: "ReportGenerationJob",
        queue_name: "reports",
        priority: 5,
        static: true,
        description: "Generates weekly summary report every Monday at 9 AM"
      },
      {
        key: "inventory_sync",
        schedule: "*/30 * * * *",
        class_name: "InventoryCheckJob",
        queue_name: "critical",
        priority: 2,
        static: true,
        description: "Synchronizes inventory levels across all warehouses every 30 minutes"
      }
    ]

    # insert skips validations and callbacks but still runs the coder.
    now = Time.current
    recurring_tasks.each do |task_attrs|
      SolidQueue::RecurringTask.insert(task_attrs.merge(
        arguments: [],
        created_at: now,
        updated_at: now
      ))
    end

    puts "  Created #{SolidQueue::RecurringTask.count} recurring tasks."
    puts ""
  end

  def seed_paused_queue
    puts "Pausing the low_priority queue..."

    SolidQueue::Pause.create!(queue_name: "low_priority")

    puts "  Paused: low_priority"
    puts ""
  end

  def print_summary
    puts "--- Seed Summary ---"
    puts "  Finished jobs:     #{SolidQueue::Job.where.not(finished_at: nil).count}"
    puts "  Pending (ready):   #{SolidQueue::ReadyExecution.count}"
    puts "  Scheduled:         #{SolidQueue::ScheduledExecution.count}"
    puts "  In-progress:       #{SolidQueue::ClaimedExecution.count}"
    puts "  Failed:            #{SolidQueue::FailedExecution.count}"
    puts "  Blocked:           #{SolidQueue::BlockedExecution.count}"
    puts "  Worker processes:  4 (1 supervisor + 3 workers)"
    puts "  Recurring tasks:   #{SolidQueue::RecurringTask.count}"
    puts "  Paused queues:     #{SolidQueue::Pause.count} (low_priority)"
    puts "  Total jobs:        #{SolidQueue::Job.count}"
    puts ""
    puts "--- Seeding complete! ---"
  end
end

DummySeeds.run
