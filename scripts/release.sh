#!/usr/bin/env bash
# release.sh
#
# Maintainer-only release automation. Run from a feature/*, feat/*, fix/* or
# hotfix/* branch with a clean working tree:
#   1. push the branch and merge it (--no-ff) into dev
#   2. cut release/vX.Y.Z from dev and bump the manifest versions there
#   3. merge the release into main, tag vX.Y.Z, back-merge main into dev
#   4. delete the release and source branches, create the GitHub Release
#
# Usage:  scripts/release.sh <patch|minor|major>
# Exit:   non-zero on the first failure; the repo is left at the failing step.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILES=(
  ".claude-plugin/plugin.json"
  ".claude-plugin/marketplace.json"
  "gemini-extension.json"
)

die() { echo "error: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

bump="${1:-}"
[[ "$bump" =~ ^(patch|minor|major)$ ]] || die "usage: scripts/release.sh <patch|minor|major>"
command -v gh >/dev/null || die "gh CLI is required"

cd "$ROOT_DIR"

source_branch="$(git symbolic-ref --short HEAD)"
[[ "$source_branch" =~ ^(feature|feat|fix|hotfix)/ ]] \
  || die "current branch '$source_branch' is not feature/*, feat/*, fix/* or hotfix/*"
git diff --quiet && git diff --cached --quiet || die "working tree has uncommitted changes"

step "Fetching origin"
git fetch origin --prune --tags

latest_tag="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)"
[[ -n "$latest_tag" ]] || die "no vX.Y.Z tag found"
current="${latest_tag#v}"

IFS=. read -r major minor patch <<<"$current"
case "$bump" in
  major) version="$((major + 1)).0.0" ;;
  minor) version="$major.$((minor + 1)).0" ;;
  patch) version="$major.$minor.$((patch + 1))" ;;
esac
tag="v$version"
release_branch="release/$tag"

sync_branch() {
  local branch="$1" local_sha remote_sha
  remote_sha="$(git rev-parse "origin/$branch")"
  if ! local_sha="$(git rev-parse -q --verify "refs/heads/$branch")"; then
    git branch "$branch" "origin/$branch"
  elif [[ "$local_sha" != "$remote_sha" ]]; then
    git merge-base --is-ancestor "$local_sha" "$remote_sha" \
      || die "local $branch has commits not on origin/$branch; reconcile it first"
    git branch -f "$branch" "origin/$branch"
  fi
}

step "Syncing dev and main with origin"
sync_branch dev
sync_branch main

echo "Releasing $source_branch: $current -> $version"

step "Pushing $source_branch"
git push -u origin "$source_branch"

step "Merging $source_branch into dev"
git checkout dev
git merge --no-ff "$source_branch" -m "Merge branch '$source_branch' into dev"
git push origin dev

step "Creating $release_branch with version $version"
git checkout -b "$release_branch"
for file in "${VERSION_FILES[@]}"; do
  sed -i "s/\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"/\"version\": \"$version\"/" "$file"
done
git add "${VERSION_FILES[@]}"
git diff --cached --quiet || git commit -m "chore(release): bump to $version and sync manifest versions"
git push -u origin "$release_branch"

step "Merging $release_branch into main and tagging $tag"
git checkout main
git merge --no-ff "$release_branch" -m "Merge branch '$release_branch' into main"
git tag -a "$tag" -m "Release $version"
git push --atomic origin main "refs/tags/$tag"

step "Back-merging main into dev"
git checkout dev
git merge --no-ff main -m "Merge branch 'main' into dev"
git push origin dev

step "Deleting $release_branch and $source_branch"
git branch -d "$release_branch" "$source_branch"
git push origin --delete "$release_branch" "$source_branch"

step "Creating GitHub Release $tag"
gh release create "$tag" --title "$tag" --generate-notes --verify-tag

echo
echo "Released $tag"
