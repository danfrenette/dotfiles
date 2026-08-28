# list all files of a specified type
function lsf {
  find . -type f -name "*.$1"
}

# Git

#git new branch
function gnb {
  git co -b $1
}

# git diff against the repository's default branch
function gdb {
  git diff "origin/$(git_default_branch)...HEAD" --histogram
}

#setup tracking information against current branch
function setupstream {
  git branch --set-upstream-to="origin/$(git_branch_name)"
}

# git rename branch
function grb {
  git branch -m $1
}

function git_branch_name {
  git branch --show-current 2>/dev/null
}

function git_default_branch {
  local branch=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  branch=${branch#origin/}
  echo "${branch:-main}"
}

# if passed an argument, g is an alias for git, otherwise return git status
function g {
  if [[ $# > 0 ]]; then
    git $@
  else
    git status
  fi
}

function gcompare {
  local remote_url=$(git config --get remote.origin.url)
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  local default_branch=$(git_default_branch)

  # Convert SSH URL to HTTPS and remove .git suffix
  remote_url=${remote_url/git@github.com:/https://github.com/}
  remote_url=${remote_url%.git}

  open "${remote_url}/compare/${default_branch}...${current_branch}"
}

function startpostgres {
  brew services start "postgresql@${1:-17}"
}

function stoppostgres {
  brew services stop "postgresql@${1:-17}"
}

function restart_postgres {
  brew services restart "postgresql@${1:-17}"
}

# Type commit messages with bare words (certain chars must be escaped)
function gcm {
  git commit -m "$*"
}

function gcam {
  git aa; git commit -m "$*"
}

# Amend last commit without editing message (like gcaa but doesn't stage unstaged files)
function gcan {
  git commit --amend --no-edit
}

function gd {
  if [[ -n "$1" ]]; then
    git diff "$@" > /tmp/changes.diff && cursor /tmp/changes.diff
  else
    git diff > /tmp/changes.diff && cursor /tmp/changes.diff
  fi
}

function gdc {
  if [[ -n "$1" ]]; then
    git diff --cached "$@" > /tmp/changes.diff && cursor /tmp/changes.diff
  else
    git diff --cached > /tmp/changes.diff && cursor /tmp/changes.diff
  fi
}

# list Rails routes by grep
function rrg {
  bin/rails routes | grep $1
}

# list Rails routes by controller name
function rrc {
  bin/rails routes -c $1
}

function rdmd {
  bin/rake db:migrate:down VERSION=$1
}

function rdmdt {
  bin/rake db:migrate:down VERSION=$1 RAILS_ENV="test"
}

function rdmu {
  bin/rake db:migrate:up VERSION=$1
}

function rdmut {
  bin/rake db:migrate:up VERSION=$1 RAILS_ENV="test"
}

function take {
  mkdir $1
  cd $1
}

# Add specific files to git stash
function shelf {
  git stash push -- $1
}

# re-write git branch
function grwb {
  git branch -D $1; git checkout -b $1;
}

#Tmux stuff

function ta {
  tmux attach-session -t $1
}

function tks {
  tmux kill-session -t $1
}
