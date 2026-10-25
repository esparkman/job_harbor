# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Job Harbor is a Rails engine (gem) providing a web UI for monitoring and managing Solid Queue jobs. Built with ViewComponents and precompiled Tailwind CSS, with no runtime styling dependencies.

## CRITICAL Workflow Requirements

**These rules are MANDATORY and must be followed without exception.**

### Session Management
- **ALWAYS run `/session-startup` at the beginning of every new session**
- **ALWAYS save memories and context to Pensieve BEFORE auto-compact occurs**

### Development Methodology
- **ALWAYS use TDD** - Write tests first, then implement. No exceptions.
- **ALWAYS use ViewComponents** - All UI components must be ViewComponents, not partials.
- **ALWAYS use the Presenter pattern** - UI logic belongs in presenters, not views or models.

## ⚠️ Global Rules Active — Read ~/.claude/CLAUDE.md

The global `~/.claude/CLAUDE.md` is loaded and ALL of its rules apply to this project.

1. Follow the **Session Initialization** instructions from the global CLAUDE.md FIRST
2. Emit the status block and delegation commitment BEFORE doing anything else
3. All delegation mandates and Rails engineering standards from the global file are in effect

## MANDATORY: Sub-Agent Delegation

Claude Code MUST delegate ALL code generation to the [Sub-Agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents#example-subagents) in `.claude/agents/`. This is **NOT optional**.

**Do NOT use built-in Explore/Plan/Code agents for any code tasks.** Use rails-agents instead:

| Task Domain | Delegate To |
|---|---|
| Investigation, architecture, system design | `@rails-architect` |
| Models, migrations, database | `@rails-model-engineer` |
| Controllers, routing, API endpoints | `@rails-controller-engineer` |
| Views, Hotwire, Stimulus, frontend | `@rails-hotwire-engineer` |
| ViewComponents, component-driven UI | `@rails-viewcomponent-engineer` |
| Authentication, sessions, magic links | `@rails-authentication` |
| Background jobs, queues, async | `@rails-background-jobs` |
| Mailers, email templates | `@rails-mailer` |
| Tests, fixtures, quality assurance | `@rails-testing-expert` |
| Security and performance | `@rails-security-performance` |
| Deployment, Docker, infrastructure | `@rails-deployment` |

**Never write code directly. Never skip delegation. Even for "simple" changes.**

### Pre-Commit Requirements
- **`bin/ci` MUST be green before committing or pushing.** It runs rubocop, bundler-audit, brakeman, the test suite and a seed replant.

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
- **ViewComponents** (18 in `app/components/job_harbor/`, all inheriting `ApplicationComponent`): Badge, Chart, EmptyState, FailureRates, InfoLine, JobFilters, JobRow, JobSearchForm, JobsTable, NavLink, Pagination, PerPageSelector, QueueCard, RefreshSelector, StatCard, StatusTabs, ThemeToggle, WorkerCard
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

### Controllers (5 endpoint controllers in `app/controllers/job_harbor/`)
- `ApplicationController` - auth base (`authorize_access`), layout and shared helpers; not an endpoint
- `DashboardController` - Root view with stats and recent failures
- `JobsController` - Index, show, search, retry/discard, bulk retry/discard
- `QueuesController` - Pause/resume queues
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
