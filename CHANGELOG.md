# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Earlier releases are documented in git history and GitHub releases.

## Unreleased

### Changed

- Search no longer matches the stored job envelope: a number finds that job ID, and text matches the job class or its arguments. Searching `job_class` or `2026` used to list nearly every job. Active Job's own argument markers (such as `_aj_symbol_keys`) still match, since they live inside the arguments.
- `PaginationComponent.new` takes `page_info:` instead of `pagy:`. Only matters if you render the component yourself.
- The dashboard's timestamp formats are registered as `Time::DATE_FORMATS[:job_harbor_timestamp]`, `[:job_harbor_timestamp_with_zone]` and `[:job_harbor_short]`. Set any of them in your own initializer to change how the dashboard shows times. No other formats are touched.

### Deprecated

- `config.primary_color` has never had any effect. Assigning it now logs a deprecation warning, and it will be removed in 1.0. Delete the line from your initializer.

### Fixed

- The dashboard's Queues count now includes paused queues that have no jobs, so it matches the Queues page.
- Auto-refresh now updates the Workers and Recurring badges in the navbar along with the page content. They used to lag until the next navigation.

### Internal

- Removed dead code: the unused `icon` argument of `NavLinkComponent` (now `NavLinkComponent.new(path:, label:, active:, badge:)`), unused CSS rules and test setup, and the empty `JobHarbor::ApplicationHelper`.

## 0.7.1 - 2026-10-23

### Fixed

- Discarding or retrying a job from a list row now returns you to the page you were on (a filtered Failed tab, a queue page, search results) instead of All Jobs. The return path is accepted only when it lies inside the dashboard's mount path.
- A return path with an encoded `..`, `//` or backslash (`%2e%2e`, `%2f`) is now rejected, and discarding the last job of a queue page lands on Queues with the "Job has been discarded." notice instead of "Queue not found."
- A page number past the last page (a stale link, or discarding the last row of a later page) now shows the last real page instead of an empty one.
- The Workers page stats are now labeled "Processes", "Live" and "Stale" and show a "Live workers" figure, so they no longer read as disagreeing with the nav badge and the dashboard's Active Workers, which count live Worker processes only.
- The Class and Queue filter dropdowns keep the active filter selected after its last job is gone, instead of falling back to "All Classes" / "All Queues" while the list is still filtered.

### Internal

- CI now runs the suite on PostgreSQL and MySQL

## 0.7.0 - 2026-10-23

### Changed

- **BREAKING:** Raised the minimum supported versions so that declared support matches what is tested:
  - Ruby >= 3.3 (was >= 3.2)
  - Rails >= 8.1 (was >= 7.1)
  - Solid Queue >= 1.0, < 2.0 (was >= 0.3)
  - ViewComponent >= 4.1 (was >= 3.0)

  Apps on Rails 7.x or 8.0, Solid Queue 0.x, or ViewComponent 3.x or 4.0 must stay on 0.6.x. Every ViewComponent 4.0.x release requires ActiveSupport < 8.1, so 4.1 is the lowest version that works with Rails 8.1. Solid Queue is capped below 2.0 because the dashboard reads Solid Queue's internal tables; support for 2.0 will ship once it's verified.
- **BREAKING:** `authorize_with` no longer defaults to `-> { true }`. When it has not been configured, the dashboard denies every request in every environment except development and test (production, staging, and so on) and logs a warning at boot. Production installs must set `config.authorize_with`; a rule you set explicitly (even `-> { true }`) is honored in every environment. Setting `authorize_with = nil` counts as unconfigured.
- **BREAKING:** Discarding a job now goes through Solid Queue's own discard, so it deletes the job row, as Solid Queue does, instead of marking the job finished. Discarded jobs no longer count as finished: they drop out of the Finished tab, "Finished (24h)", throughput and the chart. Discarding a pending job of a concurrency-limited class now releases its concurrency slot, so the next blocked job runs instead of waiting for Solid Queue's maintenance to expire the lock. Bulk discard on the Failed and Blocked tabs behaves the same way. Discarding a job that a recurring task enqueued also removes its recurring execution record (foreign key `on_delete: :cascade`), so that task's execution history and count drop by one.
- The default `poll_interval` is now 30 seconds (was 5), one of the choices in the refresh selector, and cuts database load: a dashboard load runs about 20 queries. Set `config.poll_interval = 5` to keep the old rate. A configured interval that isn't one of the standard choices (Off, 15s, 30s, 1m, 5m) now gets its own option instead of leaving the selector blank. With `enable_real_time_updates = false` the dashboard renders no refresh selector and no refresh script, whatever the browser has stored.
- Job lists order by id (newest first) instead of `created_at`, which Solid Queue's schema doesn't index, so every list no longer sorts in a temporary table.
- The job page shows the arguments the job was enqueued with, and tucks the full serialized Active Job payload into a "Full payload" block. It used to show the whole payload as the arguments.
- The retry badge shows the attempt number: a job's stored `executions` counts earlier runs, so a retried job's first retry shows (x2) and a fresh job shows no badge.
- Search matches a job's ID exactly when the query is all digits, and its Active Job ID exactly when the query is a UUID. It no longer casts the ID to text, which MySQL rejects.
- The dashboard chart no longer ends on an always-empty bucket: a range now has one bucket per interval (24 for 24 hours, was 25), and jobs enqueued in the current instant count in the last bucket. Failure rates are computed from the dashboard's 24 hour window only; `FailureStats` no longer takes a `window:` argument, and the rate colors moved into the failure rates component.
- **BREAKING:** Job arguments, the full payload and recurring task arguments are now filtered with your app's `config.filter_parameters` (read at render time), so values under keys like `password` or `token` show as `[FILTERED]`. Active Job's own `_aj_*` markers are left as they are. Arguments passed positionally (not in a hash) have no key and are still shown; a Proc filter in `filter_parameters` can scrub them by pattern, and the same Proc also scrubs error messages and backtraces, which are otherwise shown as written. Set `config.filter_parameters` to an array to use a different list, or to `false` to show raw values (any other value raises `ArgumentError`). While filtering is on, search matches job class, job ID and Active Job ID but no longer argument text, because matching hidden values would let a search reveal them.

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
- The dashboard chart fell back to one COUNT query per bucket (75 for the 24 hour range) because it called a grouping method that doesn't exist. Each series now runs one query that counts every bucket with a portable `SUM(CASE ...)`, on any database. A dashboard load drops from 91 queries to 18 on the 24 hour range and from 103 to 18 on 7 days.
- The Failure Rates card loaded every failed job id into Ruby and ran an `IN` query. It now runs two grouped counts, with the failures counted through a join.
- A `chart_range` in the URL that isn't one of the ranges highlighted no button while the chart showed 24 hours. An invalid range now falls back to the configured default, and the highlighted button matches the chart.
- Every page scrolled sideways on a phone (about 830px of content in a 390px viewport) because the navbar never wrapped. On small screens the nav links now drop to their own row, the header actions, search form, chart range buttons and pagination row wrap, job detail values break instead of stretching the page, and the dashboard's Failure Rates table scrolls inside its card like the other tables.

### Internal

- Added integration tests covering every dashboard page against real Solid Queue tables.
- Added operator tests for every dashboard action that changes data: retry, retry all, discard, discard all (failed and blocked), pause, resume and Run Now.
