# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Job Harbor is a Rails engine (gem) providing a web UI for monitoring and managing Solid Queue jobs. Built with ViewComponents and precompiled Tailwind CSS, with no runtime styling dependencies.

## Workflow

The global `~/.claude/CLAUDE.md` and `~/.claude/rails-rules.md` apply here. This section covers what is specific to this repo.

### Sessions
- Start with `/session-start`, which loads context from the Obsidian vault (`~/Documents/Obsidian Vault/job_harbor/`).
- End with `/session-end`, or `/handoff` before a `/clear`, so the next session picks up from the vault.

### Lanes
Pick the lightest lane that fits:
- **Small fix**: a typo, copy change, config tweak or one-line fix. Branch, fix it, run `bin/ci`, then commit.
- **Story**: one feature or bug you could describe in a paragraph. Write it up with `story-writer` first, then build it, get `bin/ci` green and review it once at the end.

Bigger than one story? Split it into stories you could ship on their own.

### Building
- **TDD.** Write the failing test first. Every user-visible change gets at least one operator-story test.
- **ViewComponents, not partials**, for UI.
- **Presenters and query objects** in `app/models/job_harbor/` hold UI and query logic, not views or controllers.
- Write the code directly. The agents in `.claude/agents/` (symlinked, never committed) are specialists to call when they earn it: `@rails-architect` for cross-cutting design, `@rails-security-performance` for a second pass on sensitive changes, `@rails-qa` for real-browser QA after behavior changes.
- Ground structural claims (schema, routes, associations) in live introspection: the rails MCP, else `bin/rails runner`.

### Review
Run `@dhh-code-reviewer` (or `blind-review`) once, after `bin/ci` is green, when the change adds a public interface (model, controller, generator, config setting), touches auth, deletion or security settings, or is larger than about 50 lines. Otherwise skip it and say so in one line.

### Pre-commit
- **`bin/ci` must be green before committing or pushing.** It runs rubocop, bundler-audit, brakeman, the unit and system tests and a seed replant.
- Chain it: `bin/ci && git commit && git push`, never with `;`.
- One branch and PR per change. Never commit `.claude/` (this is a public repo).

### Git Commit & PR Rules
- **NEVER mention AI assistance in commit messages or PR descriptions**
- No "Co-Authored-By" lines referencing Claude, AI, or any AI assistant
- Write commits and PRs as if authored solely by the developer

## Development Commands

### Testing
```bash
bin/ci                                      # Full gate: lint, security scans, tests, seeds
bin/rails test                              # Tests only
bin/rails test test/models/foo_test.rb      # Single test file
bin/rails test test/models/foo_test.rb:42   # Single test by line number
```
Concurrent local runs share `test/dummy/storage/test.sqlite3`, so `test/test_helper.rb` takes a lock (`test/dummy/tmp/test-suite.lock`) and a second run prints "Waiting for another test run to finish…" and waits its turn.

### Linting
```bash
bin/rubocop                    # Ruby linting (Omakase style)
bin/rubocop -a                 # Auto-fix safe violations
bundle exec rubycritic app lib # Code quality analysis
```

### Rebuilding CSS
The committed `app/assets/stylesheets/job_harbor/application.css` is compiled from `application.tailwind.css`. The tasks live in `rakelib/tailwind.rake` (maintainer-only, not packaged in the gem) and run from the repo root:
```bash
bundle exec rake job_harbor:tailwind:install   # one-time: download the standalone CLI to vendor/tailwindcss/
bundle exec rake job_harbor:tailwind:build     # compile, minified
bundle exec rake job_harbor:tailwind:watch     # recompile on change
```

### Rails Commands (via test/dummy app)
```bash
bin/rails console
bin/rails db:migrate
bin/rails routes
```

## Architecture

### Rails Engine Structure
- Mountable engine namespaced under `JobHarbor`
- Test/development uses dummy Rails app at `test/dummy/`
- The host app mounts it wherever it likes; there is no built-in default. The README documents `mount JobHarbor::Engine, at: "/job_harbor"`

### Key Patterns
- **ViewComponents** (19 in `app/components/job_harbor/`, all inheriting `ApplicationComponent`): Badge, Chart, EmptyState, FailureRates, InfoLine, JobFilters, JobRow, JobSearchForm, JobsTable, NavLink, Pagination, PerPageSelector, QueueCard, QueuePauseForm, RefreshSelector, StatCard, StatusTabs, ThemeToggle, WorkerCard
- **Presenter and query objects** (`app/models/job_harbor/`):
  - `JobPresenter` wraps SolidQueue::Job with UI logic (status, error handling, can_retry?, can_discard?)
  - `JobQuery` builds the filtered, searched, paginated job lists per status tab
  - `JobStatus` is the single list of job statuses, in display order
  - `DashboardStats`, `QueueStats`, `FailureStats` aggregate SolidQueue data
  - `ChartData` buckets job counts over time for the charts
  - `PageInfo` holds pagination state
  - `Processes` decides worker liveness
  - `SensitiveValueFilter` masks sensitive payload, error and argument values
  - `RecurringTaskArguments` reads a recurring task's stored arguments
  - `RecurringTaskQueue` resolves the queue a recurring task runs on (its own, else the job class's `queue_as`)
  - `DistinctJobValues` lists distinct queue and class names with a loose index scan (plain DISTINCT on MySQL)

### Controllers (6 endpoint controllers in `app/controllers/job_harbor/`)
- `ApplicationController` - auth base (`authorize_access`), layout and shared helpers; not an endpoint
- `DashboardController` - Root view with stats and recent failures
- `JobsController` - Index, show, search, retry/discard, bulk retry/discard
- `QueuesController` - Index, show, pause/resume queues
- `Queues::PausesController` - Pause a queue by name, including one with no jobs yet
- `WorkersController` - Monitor active workers
- `RecurringTasksController` - Index, show, manual enqueue

### Styling
- Compiled Tailwind in `app/assets/stylesheets/job_harbor/application.css` (see "Rebuilding CSS"), not inlined in the layout
- The layout is `app/views/layouts/job_harbor/application.html.erb`
- Theming uses HSL CSS custom properties (`--background` etc.) in `application.tailwind.css`; the old `--sqd-*` variables are gone
- Dark mode is class-based: a `dark` class on `<html>`, toggled by script

### SolidQueue Models Used
- `SolidQueue::Job` - Core job records
- `SolidQueue::ReadyExecution`, `ScheduledExecution`, `ClaimedExecution`, `FailedExecution`, `BlockedExecution` - Job status
- `SolidQueue::Process` - Worker processes
- `SolidQueue::Queue` - Queue definitions
- `SolidQueue::RecurringTask` - Scheduled recurring jobs

## Project Specification

Detailed implementation spec with architecture, components, and routes is in `.claude/spec/solidqueue-dashboard-spec.md`.
