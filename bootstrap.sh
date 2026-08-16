#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBY_VERSION="$(tr -d '[:space:]' < "$ROOT/.ruby-version")"

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi

  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
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
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW="$(find_brew || true)"
fi

if [[ -z "$BREW" ]]; then
  echo "Homebrew installation could not be located" >&2
  exit 1
fi

eval "$("$BREW" shellenv)"
ensure_formula "$BREW" rbenv

if ! rbenv versions --bare | grep -Fxq "$RUBY_VERSION"; then
  ensure_formula "$BREW" ruby-build
  if ! rbenv install -l | grep -Fxq "$RUBY_VERSION"; then
    "$BREW" upgrade ruby-build
  fi
  rbenv install -s "$RUBY_VERSION"
fi

echo ""
echo "=== Running installer with Ruby $RUBY_VERSION ==="
RBENV_VERSION="$RUBY_VERSION" rbenv exec ruby "$ROOT/install.rb" "$@"
