# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SolidQueue Dashboard is a Rails engine (gem) providing a web UI for monitoring and managing Solid Queue jobs. Built with ViewComponents, vanilla CSS, and zero external styling dependencies.

## CRITICAL Workflow Requirements

**These rules are MANDATORY and must be followed without exception.**

### Session Management
- **ALWAYS run `/session-startup` at the beginning of every new session**
- **ALWAYS save memories and context to Pensieve BEFORE auto-compact occurs**

### Development Methodology
- **ALWAYS use TDD** - Write tests first, then implement. No exceptions.
- **ALWAYS use ViewComponents** - All UI components must be ViewComponents, not partials.
- **ALWAYS use the Presenter pattern** - UI logic belongs in presenters, not views or models.

### Delegation to Subagents
- **MUST use Rails subagents for all implementation work** - They are experts in this stack.
- Available in `.claude/agents/`:
  - `rails-architect.md` - Architecture and design decisions
  - `rails-model-engineer.md` - Models, migrations, validations
  - `rails-controller-engineer.md` - Controllers and routing
  - `rails-viewcomponent-engineer.md` - ViewComponent implementation
  - `rails-hotwire-engineer.md` - Turbo and Stimulus
  - `rails-testing-expert.md` - Test implementation
  - `rails-authentication.md` - Auth flows
  - `rails-background-jobs.md` - Solid Queue jobs
  - `rails-security-performance.md` - Security and optimization

### Pre-Commit Requirements
- **ALL tests MUST pass before committing or pushing**
- Run: `bin/rails db:test:prepare test`
- Run: `bin/rubocop`

### Git Commit & PR Rules
- **NEVER mention AI assistance in commit messages or PR descriptions**
- No "Co-Authored-By" lines referencing Claude, AI, or any AI assistant
- Write commits and PRs as if authored solely by the developer

## Development Commands

### Testing
```bash
bin/rails db:test:prepare test              # Run all tests
bin/rails test test/models/foo_test.rb      # Single test file
bin/rails test test/models/foo_test.rb:42   # Single test by line number
```

### Linting
```bash
bin/rubocop                    # Ruby linting (Omakase style)
bin/rubocop -a                 # Auto-fix safe violations
bundle exec rubycritic app lib # Code quality analysis
```

### Rails Commands (via test/dummy app)
```bash
bin/rails console
bin/rails db:migrate
bin/rails routes
```

## Architecture

### Rails Engine Structure
- Mountable engine namespaced under `SolidqueueDashboard`
- Test/development uses dummy Rails app at `test/dummy/`
- Routes mounted at configurable path (default: `/solidqueue_dashboard`)

### Key Patterns
- **ViewComponents** (9 components in `app/components/`): StatCard, JobRow, Badge, Pagination, QueueCard, WorkerCard, NavLink, EmptyState
- **Presenter Pattern**: `JobPresenter` wraps SolidQueue::Job with UI logic (status, error handling, can_retry?, can_discard?)
- **Stats Models**: `DashboardStats` and `QueueStats` aggregate SolidQueue data

### Controllers (5)
- `DashboardController` - Root view with stats and recent failures
- `JobsController` - CRUD plus bulk retry/discard
- `QueuesController` - Pause/resume queues
- `WorkersController` - Monitor active workers
- `RecurringTasksController` - Manual enqueue

### Styling
- All CSS inlined in layout (`app/views/layouts/solidqueue_dashboard/application.html.erb`)
- CSS custom properties for theming (`--sqd-*` variables)
- Dark/light theme support via `data-theme` attribute

### SolidQueue Models Used
- `SolidQueue::Job` - Core job records
- `SolidQueue::ReadyExecution`, `ScheduledExecution`, `ClaimedExecution`, `FailedExecution`, `BlockedExecution` - Job status
- `SolidQueue::Process` - Worker processes
- `SolidQueue::Queue` - Queue definitions
- `SolidQueue::RecurringTask` - Scheduled recurring jobs

## Project Specification

Detailed implementation spec with architecture, components, and routes is in `.claude/spec/solidqueue-dashboard-spec.md`.
