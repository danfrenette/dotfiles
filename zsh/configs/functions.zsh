# list all files of a specified type
function lsf {
  find . -type f -name "*.$1"
}

# Git

#git new branch
function gnb {
  git co -b $1
}

#git diff develop
function gdb {
  git diff develop..$git_branch_name --patience
}

#setup tracking information against current branch
function setupstream {
  git branch --set-upstream-to=origin/$git_branch_name
}

# git rename branch
function grb {
  git branch -m $1
}

function git_branch_name {
  val=`git branch 2>/dev/null | grep '^*' | colrm 1 2`
  echo "$val"
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

  # Convert SSH URL to HTTPS and remove .git suffix
  remote_url=${remote_url/git@github.com:/https://github.com/}
  remote_url=${remote_url%.git}

  open "${remote_url}/compare/main...${current_branch}"
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

