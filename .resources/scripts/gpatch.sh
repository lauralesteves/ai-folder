# Generate a patch file from current branch vs base
# Usage:
#   gpatch                # diffs current branch vs origin/DEFAULT (remote HEAD)
#   gpatch main           # diffs current branch vs origin/main
function gpatch() {
  local base_branch current_branch safe_branch patch_file

  if [[ -n "$1" ]]; then
    if [[ "$1" == */* ]]; then
      base_branch="$1"
    else
      base_branch="origin/$1"
    fi
  else
    base_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')"
  fi

  if [[ -z "$base_branch" ]]; then
    echo "Error: Could not determine base branch (try: gpatch main)" >&2
    return 1
  fi

  if ! git rev-parse --verify --quiet "$base_branch" >/dev/null; then
    echo "Error: Base branch '$base_branch' not found." >&2
    return 1
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$current_branch" == "HEAD" || -z "$current_branch" ]]; then
    current_branch="$(git rev-parse --short HEAD)"
  fi

  safe_branch="${current_branch//\//_}"
  patch_file="${safe_branch}.patch"

  echo "Diffing against $base_branch..."
  if git diff --no-color "$base_branch"...HEAD > "$patch_file"; then
    echo "Patch written to $patch_file"
  else
    echo "Error creating patch." >&2
    return 1
  fi
}