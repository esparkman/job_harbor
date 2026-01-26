# SolidQueue Dashboard

A modern, self-contained dashboard for monitoring and managing [Solid Queue](https://github.com/rails/solid_queue) jobs. Built with ViewComponents and vanilla CSS for easy integration with any Rails application.

## Features

- **Dashboard Overview**: Real-time statistics for pending, scheduled, in-progress, failed, blocked, and finished jobs
- **Job Management**: View, search, retry, and discard jobs with full argument and error inspection
- **Queue Management**: Monitor queue health, pause/resume queues
- **Worker Monitoring**: Track active workers with heartbeat status detection
- **Recurring Tasks**: View and manually trigger recurring jobs
- **Real-time Updates**: Auto-refresh with configurable polling interval
- **Dark/Light Themes**: CSS variable-based theming with no external dependencies

## Installation

Add to your Gemfile:

```ruby
gem "solidqueue_dashboard"
```

Then run:

```bash
bundle install
```

## Configuration

Create an initializer at `config/initializers/solidqueue_dashboard.rb`:

```ruby
SolidqueueDashboard.configure do |config|
  # Authorization callback - must return true to allow access
  config.authorize_with = -> { current_user&.admin? }

  # Theme: :dark or :light
  config.theme = :dark

  # Primary accent color
  config.primary_color = "amber"

  # Jobs per page
  config.jobs_per_page = 25

  # Enable recurring tasks management
  config.enable_recurring_tasks = true

  # Enable auto-refresh
  config.enable_real_time_updates = true

  # Poll interval in seconds
  config.poll_interval = 5
end
```

## Mounting

Mount the engine in your routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Basic mount
  mount SolidqueueDashboard::Engine, at: "/jobs"

  # Or with authentication constraint
  authenticated :user, ->(u) { u.admin? } do
    mount SolidqueueDashboard::Engine, at: "/admin/jobs"
  end
end
```

## Authorization

The dashboard uses a configurable authorization callback. Return `true` to allow access:

```ruby
# Allow all authenticated users
config.authorize_with = -> { current_user.present? }

# Require admin role
config.authorize_with = -> { current_user&.admin? }

# Use Pundit or similar
config.authorize_with = -> { authorize(:solid_queue, :manage?) }
```

## Dependencies

- Rails >= 7.1
- Solid Queue >= 0.3
- ViewComponent >= 3.0

## License

MIT License. See [LICENSE](LICENSE) for details.
