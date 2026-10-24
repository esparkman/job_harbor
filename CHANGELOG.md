# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Earlier releases are documented in git history and GitHub releases.

## 0.7.0 - Unreleased

### Changed

- **BREAKING:** Raised the minimum supported versions so that declared support matches what is tested:
  - Ruby >= 3.3 (was >= 3.2)
  - Rails >= 8.1 (was >= 7.1)
  - Solid Queue >= 1.0, < 2.0 (was >= 0.3)
  - ViewComponent >= 4.1 (was >= 3.0)

  Apps on Rails 7.x or 8.0, Solid Queue 0.x, or ViewComponent 3.x or 4.0 must stay on 0.6.x. Every ViewComponent 4.0.x release requires ActiveSupport < 8.1, so 4.1 is the lowest version that works with Rails 8.1. Solid Queue is capped below 2.0 because the dashboard reads Solid Queue's internal tables; support for 2.0 will ship once it's verified.
- **BREAKING:** `authorize_with` no longer defaults to `-> { true }`. When it has not been configured, the dashboard denies every request in every environment except development and test (production, staging, and so on) and logs a warning at boot. Production installs must set `config.authorize_with`; a rule you set explicitly (even `-> { true }`) is honored in every environment. Setting `authorize_with = nil` counts as unconfigured.
- **BREAKING:** Discarding a job now goes through Solid Queue's own discard, so it deletes the job row, as Solid Queue does, instead of marking the job finished. Discarded jobs no longer count as finished: they drop out of the Finished tab, "Finished (24h)", throughput and the chart. Discarding a pending job of a concurrency-limited class now releases its concurrency slot, so the next blocked job runs instead of waiting for Solid Queue's maintenance to expire the lock. Bulk discard on the Failed and Blocked tabs behaves the same way. Discarding a job that a recurring task enqueued also removes its recurring execution record (foreign key `on_delete: :cascade`), so that task's execution history and count drop by one.
- The default `poll_interval` is now 30 seconds (was 5), one of the choices in the refresh selector, and cuts database load: a dashboard load runs about 90 queries. Set `config.poll_interval = 5` to keep the old rate. A configured interval that isn't one of the standard choices (Off, 15s, 30s, 1m, 5m) now gets its own option instead of leaving the selector blank. With `enable_real_time_updates = false` the dashboard renders no refresh selector and no refresh script, whatever the browser has stored.
- Job lists order by id (newest first) instead of `created_at`, which Solid Queue's schema doesn't index, so every list no longer sorts in a temporary table.
- The job page shows the arguments the job was enqueued with, and tucks the full serialized Active Job payload into a "Full payload" block. It used to show the whole payload as the arguments.
- The retry badge shows the attempt number: a job's stored `executions` counts earlier runs, so a retried job's first retry shows (x2) and a fresh job shows no badge.
- Search matches a job's ID exactly when the query is all digits, and its Active Job ID exactly when the query is a UUID. It no longer casts the ID to text, which MySQL rejects.

### Added

- Ruby 4.0 support.
- CI now tests three lanes: the floor (the minimum supported versions), the latest releases of everything, and the committed lockfile.

### Fixed

- Clicking "Run Now" on a recurring task twice in quick succession enqueued the job twice (for jobs on the Solid Queue adapter). Run Now now records the run at whole-second precision, so clicks within the same second collapse into one and the second click is told nothing was enqueued.
- "Run Now" on a recurring task whose job class isn't defined in the app returned a 500 (`NoMethodError`). It now shows "Task 'x' can't run: X isn't a job class defined in this app." and enqueues nothing.
- The Workers page now shows the queues each worker polls (they never rendered), labels every process by kind (Worker, Dispatcher, Scheduler, Supervisor), and marks a process whose heartbeat has gone quiet "Stale" instead of "Blocked". The "Workers" count in the navigation and the dashboard's "Active Workers" card now agree: both count live processes of kind Worker. "Live" now follows Solid Queue's `process_alive_threshold` (5 minutes by default) everywhere instead of a hard-coded five minutes.
- A denied request on a host app with no root route raised `NoMethodError` and returned 500. It now returns 403, as do denied non-HTML requests.
- The engine's maintainer-only Tailwind rake tasks no longer load into host apps (they defined helper methods on Object).
- A rule that redirects or renders itself and then returns false no longer raises `DoubleRenderError`.
- The engine failed to load on Ruby 4.0 because `ostruct` is no longer a default gem. Pagination now uses a `PageInfo` value object instead of `OpenStruct`.
- Confirmation dialogs on Discard, Discard All, and Retry All never appeared, so the buttons acted immediately. The message now sits on the form and the layout shows a browser confirm before it submits.
- "Retry All" and "Discard All" on a filtered list acted on every failed job, ignoring the class and queue filters. They now act only on the jobs the list shows, and the buttons and confirmations say how many ("Retry 3 failed jobs").
- Retry All ran about nine queries per job. It now uses Solid Queue's own bulk retry in batches of 500. Like Solid Queue's `retry_all`, it no longer resets each job's execution counters the way retrying a single job does, so a bulk-retried job keeps its attempt count toward `retry_on` limits.
- The Blocked tab had no Discard All button even though the endpoint existed. It now shows "Discard N blocked jobs".
- Queue pages paginated before filtering by queue, so pages came up short or empty and totals counted every queue. They now paginate within the queue. Their job rows are the same as on the Jobs page, so Discard and the running duration show there too, and queues show a Blocked count.
- Pausing a queue twice (a double-submit or a stale page) raised a database error. Pause and resume now go through Solid Queue's own queue API.
- Notices said "1 jobs discarded." and "1 jobs queued for retry."; they now pluralize correctly.
- Run Now always said "Task '...' has been enqueued." even when nothing was enqueued: a second click in the same second, or a job that refuses to enqueue. It now shows an alert saying the task was not enqueued, and no longer shows Solid Queue's exception text in the flash.
- A recurring task's "Total Executions" stopped counting at 20, the size of the Recent Executions list. It now counts every execution.
- "Last Run" and "Run At" on a recurring task showed when the record was written. They now show the time the execution was scheduled for, and the list is ordered by it.
- Auto-refresh never updated the page: it looked for an element the layout no longer had, so every poll fetched the page and threw it away. The page content now refreshes in place, redraws the chart, skips a refresh while a button, link or field in the page has focus or text is selected, never lets overlapping requests overwrite each other, and ignores redirects and error responses. The job detail page no longer auto-refreshes, so its backtrace keeps its scroll position.
- Every inline script now carries the host's CSP nonce, and the dashboard no longer uses inline `style` attributes, so it works under a strict `script-src` and `style-src`.
- Removed dead Stimulus `data-action` attributes from the theme toggle, refresh selector and per-page selector (the dashboard loads no Stimulus).
- Job lists ran one to five status queries per row (a 100-job page took about 360 queries). They now preload each job's executions and read the status from them: a 100-job page takes 17 queries, and the count no longer grows with the page size.
- Searching for `%` matched every job, and `_` matched any character. Both are now literal. "Found 1 results" now reads "Found 1 result". Search is now case-insensitive on every database (Postgres's `LIKE` was case-sensitive).

### Internal

- Added integration tests covering every dashboard page against real Solid Queue tables.
- Added operator tests for every dashboard action that changes data: retry, retry all, discard, discard all (failed and blocked), pause, resume and Run Now.
