#!/bin/bash

set -e

UPSTREAM_URL="https://github.com/gitroomhq/postiz-docs.git"
BRANCH="main"
STASHED=false

cd "$(dirname "$0")"

ask() {
  while true; do
    read -r -p "$1 (y/n): " choice
    case "$choice" in
      y|Y) return 0 ;;
      n|N) return 1 ;;
      *) echo "   Please enter y or n." ;;
    esac
  done
}

echo ""
echo "======================================"
echo "  Syncing postiz-docs with upstream"
echo "======================================"
echo ""

# --- Check for uncommitted changes ---
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  You have uncommitted changes:"
  git status --short
  echo ""
  if ask "   Stash them temporarily so we can switch branches?"; then
    git stash push -m "sync-upstream: auto-stash"
    STASHED=true
    echo "   ✓ Changes stashed."
  else
    echo "   ✗ Cannot proceed without stashing. Exiting."
    exit 1
  fi
fi

# --- Check for upstream remote ---
echo ""
if ! git remote get-url upstream &>/dev/null; then
  echo "ℹ️  No upstream remote found."
  if ask "   Add upstream remote ($UPSTREAM_URL)?"; then
    git remote add upstream "$UPSTREAM_URL"
    echo "   ✓ Upstream remote added."
  else
    echo "   ✗ Cannot sync without upstream remote. Exiting."
    $STASHED && git stash pop
    exit 1
  fi
else
  echo "✓ Upstream remote: $(git remote get-url upstream)"
fi

# --- Fetch upstream ---
echo ""
echo "==> Fetching upstream changes..."
git fetch upstream
echo "   ✓ Fetch complete."

# --- Switch to main if on another branch ---
CURRENT_BRANCH=$(git branch --show-current)
echo ""
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "ℹ️  You are currently on branch '$CURRENT_BRANCH'."
  if ask "   Switch to '$BRANCH' to apply upstream changes?"; then
    git checkout $BRANCH
    echo "   ✓ Switched to '$BRANCH'."
  else
    echo "   ✗ Cannot sync without switching to '$BRANCH'. Exiting."
    $STASHED && git stash pop
    exit 1
  fi
fi

# --- Check if already up to date ---
LOCAL=$(git rev-parse HEAD)
UPSTREAM_HEAD=$(git rev-parse upstream/$BRANCH)

echo ""
if [ "$LOCAL" = "$UPSTREAM_HEAD" ]; then
  echo "✓ Already up to date with upstream. Nothing to merge."
else
  # --- Merge ---
  echo "ℹ️  New changes found in upstream."
  if ask "   Merge upstream/$BRANCH into your '$BRANCH'?"; then
    git merge upstream/$BRANCH --no-edit
    echo "   ✓ Merge complete."
  else
    echo "   ✗ Skipping merge."
  fi

  # --- Push ---
  echo ""
  if ask "   Push updated '$BRANCH' to your fork (origin)?"; then
    git push origin $BRANCH
    echo "   ✓ Pushed to origin/$BRANCH."
  else
    echo "   ✗ Skipping push. Your local '$BRANCH' is updated but not pushed."
  fi
fi

# --- Switch back to original branch ---
echo ""
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  if ask "   Switch back to your original branch '$CURRENT_BRANCH'?"; then
    git checkout $CURRENT_BRANCH
    echo "   ✓ Switched back to '$CURRENT_BRANCH'."
  fi
fi

# --- Restore stash ---
if [ "$STASHED" = true ]; then
  echo ""
  if ask "   Restore your stashed changes?"; then
    git stash pop
    echo "   ✓ Stash restored."
  else
    echo "   ✗ Stash left in place. Run 'git stash pop' manually when ready."
  fi
fi

echo ""
echo "======================================"
echo "  Done!"
echo "======================================"
echo ""
