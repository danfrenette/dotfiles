#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUBY_VERSION="$(tr -d '[:space:]' < "$ROOT/.ruby-version")"
DRY_RUN=false
HELP=false
ONLY_PHASES=()

print_usage() {
  cat <<'USAGE'
Usage: install.rb [options]
        --dry-run                    Print the plan without applying it
        --yes                        Apply the plan without confirmation
        --only PHASE                 Run only homebrew, opencode2, mappings, neovim, or skills
    -h, --help                       Show this help
USAGE
}

usage_error() {
  echo "$1" >&2
  print_usage >&2
  exit 64
}

validate_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --yes)
        shift
        ;;
      --only)
        [[ $# -gt 1 ]] || usage_error "missing argument: --only"
        ONLY_PHASES+=("$2")
        shift 2
        ;;
      --only=*)
        ONLY_PHASES+=("${1#--only=}")
        [[ -n "${ONLY_PHASES[-1]}" ]] || usage_error "missing argument: --only"
        shift
        ;;
      -h|--help)
        HELP=true
        shift
        ;;
      --*)
        usage_error "invalid option: $1"
        ;;
      *)
        usage_error "Unexpected arguments: $1"
        ;;
    esac
  done

  if [[ "$HELP" == true ]]; then
    print_usage
    exit 0
  fi
  for phase in "${ONLY_PHASES[@]:-}"; do
    [[ -n "$phase" ]] || continue
    if [[ "$phase" != "homebrew" && "$phase" != "opencode2" && "$phase" != "mappings" && "$phase" != "neovim" && "$phase" != "skills" ]]; then
      usage_error "Unsupported phase: $phase"
    fi
  done
}

validate_arguments "$@"

find_brew() {
  local path
  if path="$(command -v brew 2>/dev/null)" && [[ -f "$path" && -x "$path" ]]; then
    echo "$path"
    return
  fi

  local candidate candidates
  local -a brew_candidates
  candidates="${HOMEBREW_CANDIDATES:-/opt/homebrew/bin/brew:/usr/local/bin/brew}"
  IFS=: read -ra brew_candidates <<< "$candidates"
  for candidate in "${brew_candidates[@]}"; do
    if [[ -f "$candidate" && -x "$candidate" ]]; then
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
