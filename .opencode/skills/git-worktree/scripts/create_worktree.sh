#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create_worktree.sh <branch> [destination] [start-point]

Creates a sibling Git worktree, checks out (or creates) <branch>, and runs
flutter pub get in the worktree's app directory.
EOF
}

if (( $# < 1 || $# > 3 )); then
  usage >&2
  exit 64
fi

branch=$1
repository_root=$(git rev-parse --show-toplevel)
repository_name=$(basename "$repository_root")
destination=${2:-"$(dirname "$repository_root")/${repository_name}-${branch//\//-}"}
start_point=${3:-HEAD}

git check-ref-format --branch "$branch" >/dev/null

if [[ -e "$destination" ]]; then
  printf 'Destination already exists: %s\n' "$destination" >&2
  exit 73
fi

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
