#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create_worktree.sh <branch> [destination] [start-point]

Creates a Git worktree under ../activity-monitor.worktrees relative to the main
checkout by default, checks out (or creates) <branch>, and runs flutter pub get.
EOF
}

if (( $# < 1 || $# > 3 )); then
  usage >&2
  exit 64
fi

branch=$1
common_git_dir=$(git rev-parse --path-format=absolute --git-common-dir)
main_checkout=$(dirname "$common_git_dir")
destination=${2:-"$(dirname "$main_checkout")/activity-monitor.worktrees/${branch//\//-}"}
start_point=${3:-HEAD}

git check-ref-format --branch "$branch" >/dev/null

if [[ -e "$destination" ]]; then
  printf 'Destination already exists: %s\n' "$destination" >&2
  exit 73
fi

mkdir -p "$(dirname "$destination")"

if git show-ref --verify --quiet "refs/heads/$branch"; then
  git worktree add "$destination" "$branch"
else
  git worktree add -b "$branch" "$destination" "$start_point"
fi

(
  cd "$destination/app"
  flutter pub get
)

printf 'Worktree ready: %s\n' "$destination"
