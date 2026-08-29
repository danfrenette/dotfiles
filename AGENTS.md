# Agent Guidance

## Repository Purpose

This is a personal dotfiles repository for Apple Silicon Macs. The README is
the user-facing setup guide; this file describes how to change the repository
safely.

## Architecture

- `Config` centralizes repository and home-directory paths.
- `PhaseCatalog` is the composition root: it injects dependencies and assembles
  setup and refresh workflows.
- Installer phases separate planning from application. Planning must not mutate
  the machine.
- `config/mappings.yml` declares dotfile sources and targets.
- `config/skills.yml` declares personal and community skill catalogs.
- Repository-owned configuration is trusted input. Validate data only at real
  external seams, not between internal collaborators.

## Changes

- Inject dependencies explicitly from the composition root.
- Prefer small, cohesive objects that respond to messages over callers that
  inspect hashes, types, or collaborator state.
- Use TDD for behavior changes. Agree on the public seam, observe a failing
  test, add the minimum implementation, and then run the broader suite.
- Keep changes focused and avoid speculative compatibility or abstractions.
- Preserve unrelated worktree changes.
- Do not modify sibling repositories such as `../skills` unless the task
  explicitly includes them.

## Safety

- `bin/dotfiles setup` installs software and changes files under `$HOME`.
- `dotfiles refresh` changes symlinks and installs skills.
- Use `bin/dotfiles setup --dry-run` or `bin/dotfiles refresh --dry-run` for
  routine verification.
- Do not run a mutating setup, refresh, Homebrew bundle, or plugin installation
  without explicit approval.
- Never remove backups or replace existing home-directory files to make a test
  pass.

## Verification

- Run a focused test with `ruby -Itest path/to/test.rb` while iterating.
- Run `bundle exec rake` before considering Ruby changes complete; it runs the
  full test suite and StandardRB.
- Run `git diff --check` for every change.
- Use `zsh -n`, headless Neovim, or an isolated tmux server when changing those
  configurations.

## Delivery

Make changes on a branch and put them in a pull request before merging into
`main`. Keep commits independently reviewable and report any verification that
could not be run.
