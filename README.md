# My Dotfiles

These are the configuration files that serve as the foundation of my career as
a professional Keyboard Toucher™

### Philosophy

Aside from a handful of industry standard pieces of software (e.g. Slack,
Cursor) I try to lean on tools that focus on doing one thing really, really
well. Other than that, the only thing I can say is I'm a really big fan of
aliases. You'll find I've added them for just about everything I can think of.
If you find any of them useful, let me know.

## Installation

### Quick Start

```bash
git clone https://github.com/danfrenette/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
./bootstrap.sh
```

This will:

1. Install Homebrew (if not already installed)
2. Install packages from `Brewfile`
3. Symlink config files to their target locations (backing up replaced files to `.backup`)
4. Install agent skills into OpenCode
5. Install Neovim plugins

### Manual Installation

```bash
# Install Ruby dependencies
bundle install

# Full installation
./install.rb

# Skip Homebrew packages (just symlink configs)
./install.rb --skip-brew

# Dry run (shows what would be backed up/replaced)
./install.rb --dry-run

# Install or update agent skills only
./install.rb --only skills
```

### Development

```bash
bundle exec rake test       # Run tests
bundle exec rake standard   # Run linter
bundle exec rake brew       # Install Homebrew packages only
```

## What's Included

- **Git** - Config with way too many aliases, global gitignore I don't use, commit template that I also don't use.
- **Zsh** - Shell config, aliases (too many), functions (not enough), some decent plugins
- **Neovim** - Lua config with vim-plug (tpope essentials, vim-test, copilot)
- **Tmux** - TPM, catppuccin theme, vim-tmux-navigator, session persistence
- **Ruby** - irbrc/pryrc with awesome_print and helpers
- **OpenCode** - Personal skills installed from `danfrenette/skills`
- **Homebrew** - CLI tools and casks via Brewfile

## Agent Skills

Run `./install.rb --only skills` to launch the pinned [skills CLI](https://github.com/vercel-labs/skills). It installs selected skills from `danfrenette/skills` into the global OpenCode configuration.

## Adding New Dotfiles

1. Add source files to the appropriate directory
2. Update `lib/config.rb` with the new mappings
3. Run `./install.rb --skip-brew` to create symlinks

## Backup Behavior

When a target file already exists and is not a symlink, the installer backs it
up with a `.backup` suffix before creating the symlink.

## Inspiration

Here's a few other dotfiles repos that I ~~stole a bunch of stuff from~~ was inspired by:

- [Ben Orenstein's dotfiles][r00k]
- [Blake Williams' dotfiles][blakewilliams]
- [Chris Toomey's dotfiles][christoomey]
- [Gabe Berke-Williams' dotfiles][gabebw]

[r00k]: https://github.com/r00k/dotfiles
[blakewilliams]: https://github.com/BlakeWilliams/dotfiles
[christoomey]: https://github.com/christoomey/dotfiles
[gabebw]: https://github.com/gabebw/dotfiles
