#!/bin/bash
set -e

echo "=== Dotfiles Bootstrap ==="

# Check for Homebrew
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH for Apple Silicon
  if [[ $(uname -m) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  echo "Homebrew already installed"
fi

# Run the Ruby installer
echo ""
echo "=== Running installer ==="
cd "$(dirname "$0")"
./install.rb
