# SolidQueue Dashboard Specification

## Overview

SolidQueue Dashboard is a Rails engine providing a web UI for monitoring and managing Solid Queue jobs. It is self-contained with zero external styling dependencies.

## Design Principles

1. **Self-Contained** - No external CSS framework, no Node.js build pipeline
2. **ViewComponents** - All UI components use ViewComponent (no partials)
3. **Presenter Pattern** - JobPresenter wraps SolidQueue models for UI logic
4. **CSS Variables** - All theming via `--sqd-*` custom properties
5. **Rails Engine** - Proper namespace isolation, mountable at any path

## Architecture

### Engine Namespace

All code is namespaced under `SolidqueueDashboard`:
- Controllers inherit from `SolidqueueDashboard::ApplicationController`
- Components inherit from `SolidqueueDashboard::ApplicationComponent`
- Routes are drawn within `SolidqueueDashboard::Engine.routes`

### Controllers

| Controller | Purpose |
|------------|---------|
| `DashboardController` | Root view with job statistics and recent failures |
| `JobsController` | List, search, show, retry, discard jobs (with bulk actions) |
| `QueuesController` | View queues, pause/resume |
| `WorkersController` | Monitor active workers |
| `RecurringTasksController` | View and manually trigger recurring jobs |

### ViewComponents (9)

| Component | Purpose |
|-----------|---------|
| `StatCardComponent` | Displays job statistics with icons |
| `JobRowComponent` | Table row for job listings |
| `BadgeComponent` | Status badges (pending, failed, etc.) |
| `PaginationComponent` | Pagination controls |
| `QueueCardComponent` | Queue status card |
| `WorkerCardComponent` | Worker status card |
| `NavLinkComponent` | Navigation links with active state |
| `EmptyStateComponent` | Empty state UI |
| `ApplicationComponent` | Base component class |

### Models & Presenters

**DashboardStats** - Calculates and caches dashboard statistics:
- `pending_count`, `scheduled_count`, `in_progress_count`, `failed_count`, `blocked_count`, `finished_count`
- `workers_count`, `queues_count`, `throughput_per_hour`, `recent_failures`

**JobPresenter** - Wraps `SolidQueue::Job` with presentation logic:
- Delegated: `id`, `created_at`, `updated_at`, `queue_name`, `priority`, `active_job_id`, `arguments`, `scheduled_at`, `finished_at`
- Methods: `status`, `arguments_preview`, `error_message`, `error_backtrace`, `can_retry?`, `can_discard?`
- Class methods: `find()`, `all_with_status()`, `search()` with pagination

**QueueStats** - Queue health and metrics

### SolidQueue Models Used

The dashboard reads from these SolidQueue tables:
- `SolidQueue::Job` - Core job records
- `SolidQueue::ReadyExecution` - Jobs ready to run
- `SolidQueue::ScheduledExecution` - Scheduled future jobs
- `SolidQueue::ClaimedExecution` - Jobs currently running
- `SolidQueue::FailedExecution` - Failed jobs with error info
- `SolidQueue::BlockedExecution` - Blocked jobs (concurrency limits)
- `SolidQueue::Process` - Worker processes
- `SolidQueue::Queue` - Queue definitions
- `SolidQueue::RecurringTask` - Scheduled recurring jobs

## Configuration

```ruby
SolidqueueDashboard.configure do |config|
  # Authorization callback (must return truthy to allow access)
  config.authorize_with = -> { current_user&.admin? }

  # Theme: :dark (default) or :light
  config.theme = :dark

  # Primary color for accents
  config.primary_color = "amber"

  # Jobs per page in listings
  config.jobs_per_page = 25

  # Enable recurring tasks UI
  config.enable_recurring_tasks = true

  # Enable real-time updates via polling
  config.enable_real_time_updates = true

  # Poll interval in seconds
  config.poll_interval = 5
end
```

## Routes

Mount the engine in your application:

```ruby
# config/routes.rb
mount SolidqueueDashboard::Engine, at: "/solidqueue"
```

### Available Routes

```
GET  /                           # dashboard#index (root)
GET  /jobs                       # jobs#index (all jobs)
GET  /jobs/:id                   # jobs#show
POST /jobs/:id/retry             # jobs#retry
DELETE /jobs/:id/discard         # jobs#discard
POST /jobs/retry_all             # jobs#retry_all (bulk)
DELETE /jobs/discard_all         # jobs#discard_all (bulk)
GET  /jobs/status/:status        # jobs#index with status filter
GET  /search                     # jobs#search
GET  /queues                     # queues#index
GET  /queues/:name               # queues#show
POST /queues/:name/pause         # queues#pause
DELETE /queues/:name/resume      # queues#resume
GET  /workers                    # workers#index
GET  /recurring_tasks            # recurring_tasks#index
GET  /recurring_tasks/:id        # recurring_tasks#show
POST /recurring_tasks/:id/enqueue_now  # recurring_tasks#enqueue_now
```

## Styling

### CSS Variables

All styling uses CSS custom properties for theming:

```css
/* Colors */
--sqd-primary, --sqd-success, --sqd-warning, --sqd-danger, --sqd-info

/* Backgrounds */
--sqd-bg-primary, --sqd-bg-secondary, --sqd-bg-tertiary, --sqd-border

/* Text */
--sqd-text-primary, --sqd-text-secondary, --sqd-text-muted
```

### Theme Support

Themes are applied via `data-theme` attribute on the body:
- Dark theme (default): `data-theme="dark"`
- Light theme: `data-theme="light"`

### Layout

- Fixed sidebar (240px width)
- Main content area with padding
- Responsive design via CSS variables

## Testing

### Dummy Application

Tests use a complete Rails app at `test/dummy/`:
- SQLite3 database
- Routes mount engine at `/solidqueue_dashboard`
- CI configuration in `test/dummy/config/ci.rb`

### Test Structure

```
test/
├── test_helper.rb           # Test setup, loads dummy app
├── dummy/                   # Complete Rails app for testing
├── integration/             # Integration tests
└── solidqueue_dashboard_test.rb
```
