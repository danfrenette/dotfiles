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

### Warning/Preface/Sanity Check

I made this installer because it's a fun little demo of how I like to compose
classes in Ruby, and because I like to format my machines more often than most,
but it's probably not the best way for you to get value out of this.

I recommend pointing your agent at the repo and chatting about things that might be useful to you over actually running what follows. That said, if you're really interested in running my software on some _really_ important configurations, have at it!

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
4. Install agent skills into OpenCode and Cursor
5. Install Neovim plugins

### Manual Installation

```bash
# Install Ruby dependencies
bundle install

# Full installation
bin/dotfiles setup

# Refresh dotfiles and skills after restarting your shell
dotfiles refresh

# Dry run (shows what would be backed up/replaced)
bin/dotfiles setup --dry-run

# Preview a routine refresh
dotfiles refresh --dry-run
```

Setup installs the `dotfiles` command in `~/.local/bin`. Restart your shell
(or run `exec zsh`) before using it.

### Development

```bash
bundle exec rake test       # Run tests
bundle exec rake standard   # Run linter
```

## What's Included

- **Git** - Config with way too many aliases, XDG global ignores, and a commit template
- **Zsh** - Shell config, aliases, Homebrew-managed plugins, and mise-managed Node
- **Neovim** - Lua config with vim-plug (tpope essentials, vim-test, copilot)
- **Tmux** - TPM, catppuccin theme, vim-tmux-navigator, session persistence
- **Ruby** - irbrc/pryrc with awesome_print and helpers
- **Agent skills** - Personal skills installed from `danfrenette/skills` for OpenCode and Cursor
- **Homebrew** - CLI tools, versioned PostgreSQL servers, and casks via Brewfile

## Agent Skills

Run `dotfiles refresh` to update dotfiles and launch the pinned [skills CLI](https://github.com/vercel-labs/skills). It installs selected skills from `danfrenette/skills` into the global OpenCode and Cursor configurations.

## Adding New Dotfiles

1. Add source files to the appropriate directory
2. Add the source and target to `config/mappings.yml`
3. Run `dotfiles refresh` to create symlinks and refresh skills

## Verification

Use `./bootstrap.sh --help`, `bin/dotfiles --help`, `bin/dotfiles setup --dry-run`, `dotfiles refresh --dry-run`, and `bundle exec rake` to verify the setup safely. Setup installs baseline technology and then personal configuration; Refresh updates dotfiles and skills on an already set-up machine. Do not use `--yes` unless you intend to apply the complete selected workflow.

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
