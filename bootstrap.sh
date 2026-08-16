#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBY_VERSION="$(tr -d '[:space:]' < "$ROOT/.ruby-version")"
DRY_RUN=false

for argument in "$@"; do
  if [[ "$argument" == "--dry-run" ]]; then
    DRY_RUN=true
    break
  fi
done

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi

  local candidate candidates
  local -a brew_candidates
  candidates="${HOMEBREW_CANDIDATES:-/opt/homebrew/bin/brew:/usr/local/bin/brew}"
  IFS=: read -ra brew_candidates <<< "$candidates"
  for candidate in "${brew_candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done

  return 1
}

ensure_formula() {
  local brew="$1"
  local formula="$2"

  if ! "$brew" list --versions "$formula" >/dev/null 2>&1; then
    "$brew" install "$formula"
  fi
}

echo "=== Dotfiles Bootstrap ==="

BREW="$(find_brew || true)"
if [[ -z "$BREW" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "Would install Homebrew with the official installer"
    exit 0
  fi

  echo "Installing Homebrew..."
  if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    echo "Homebrew installation failed" >&2
    exit 1
  fi
  BREW="$(find_brew || true)"
fi

if [[ -z "$BREW" ]]; then
  echo "Homebrew installation could not be located" >&2
  exit 1
fi

if ! BREW_SHELLENV="$("$BREW" shellenv)"; then
  echo "Homebrew shell environment could not be loaded" >&2
  exit 1
fi
if ! eval "$BREW_SHELLENV"; then
  echo "Homebrew shell environment could not be loaded" >&2
  exit 1
fi

if ! "$BREW" list --versions rbenv >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "Would install Homebrew formula: rbenv"
    exit 0
  fi
  "$BREW" install rbenv
elif ! command -v rbenv >/dev/null 2>&1; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "Would reinstall Homebrew formula: rbenv"
    exit 0
  fi
  "$BREW" reinstall rbenv
fi

if ! command -v rbenv >/dev/null 2>&1; then
  echo "rbenv installation could not be located" >&2
  exit 1
fi

if ! rbenv versions --bare | grep -Fxq "$RUBY_VERSION"; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "Would install Ruby $RUBY_VERSION with rbenv"
    exit 0
  fi

  ensure_formula "$BREW" ruby-build
  if ! rbenv install -l | grep -Fxq "$RUBY_VERSION"; then
    "$BREW" upgrade ruby-build
  fi
  rbenv install -s "$RUBY_VERSION"
fi

echo ""
echo "=== Running installer with Ruby $RUBY_VERSION ==="
RBENV_VERSION="$RUBY_VERSION" rbenv exec ruby "$ROOT/install.rb" "$@"
