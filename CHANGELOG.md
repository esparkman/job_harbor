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

### Added

- Ruby 4.0 support.
- CI now tests three lanes: the floor (the minimum supported versions), the latest releases of everything, and the committed lockfile.

### Fixed

- A denied request on a host app with no root route raised `NoMethodError` and returned 500. It now returns 403, as do denied non-HTML requests.
- A rule that redirects or renders itself and then returns false no longer raises `DoubleRenderError`.
- The engine failed to load on Ruby 4.0 because `ostruct` is no longer a default gem. Pagination now uses a `PageInfo` value object instead of `OpenStruct`.

### Internal

- Added integration tests covering every dashboard page against real Solid Queue tables.
- Added operator tests for every dashboard action that changes data: retry, retry all, discard, discard all (failed and blocked), pause, resume and Run Now.
