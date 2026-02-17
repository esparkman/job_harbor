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
