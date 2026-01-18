#!/bin/bash
# Script to merge changes from worktree to main repository

set -e

WORKTREE_DIR="/Users/oliverli/.claude-worktrees/UniControl/wonderful-lalande"
MAIN_REPO="/Users/oliverli/develop/UniControl"
BRANCH_NAME="wonderful-lalande"

echo "======================================"
echo "UniControl - Merge to Main Repository"
echo "======================================"
echo ""
echo "Worktree: $WORKTREE_DIR"
echo "Main Repo: $MAIN_REPO"
echo "Branch: $BRANCH_NAME"
echo ""

# Check if main repo exists
if [ ! -d "$MAIN_REPO" ]; then
    echo "❌ Error: Main repository not found at $MAIN_REPO"
    exit 1
fi

# Check if worktree has uncommitted changes
cd "$WORKTREE_DIR"
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Warning: Worktree has uncommitted changes"
    echo "Please commit or stash them first"
    git status
    exit 1
fi

echo "✅ Worktree is clean"
echo ""

# Show what will be merged
echo "📋 Commits to be merged:"
git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline HEAD~2..HEAD
echo ""

# Ask for confirmation
read -p "Ready to merge to main repository? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Merge cancelled"
    exit 0
fi

# Switch to main repository
cd "$MAIN_REPO"
echo ""
echo "📂 Switched to main repository: $(pwd)"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
echo ""

# Determine main branch name
if git show-ref --verify --quiet refs/heads/main; then
    MAIN_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
    MAIN_BRANCH="master"
else
    echo "❌ Error: Could not find main or master branch"
    exit 1
fi

echo "Main branch: $MAIN_BRANCH"

# Switch to main branch if not already there
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
    echo "Switching to $MAIN_BRANCH..."
    git checkout "$MAIN_BRANCH"
fi

# Fetch the branch from worktree
echo ""
echo "🔄 Fetching branch from worktree..."

# Add worktree as temporary remote if not exists
if ! git remote | grep -q worktree; then
    git remote add worktree "$WORKTREE_DIR"
fi

git fetch worktree "$BRANCH_NAME"

# Merge the branch
echo ""
echo "🔀 Merging $BRANCH_NAME into $MAIN_BRANCH..."

if git merge "worktree/$BRANCH_NAME" --no-ff -m "Merge modular refactoring from $BRANCH_NAME

Refactored UniControl into modular architecture with DSL support.
See REFACTORING_SUMMARY.md for details."; then
    echo ""
    echo "✅ Merge successful!"
    echo ""

    # Show merge stats
    echo "📊 Changes:"
    git diff --stat HEAD~1
    echo ""

    # Verify build
    echo "🔨 Verifying build..."
    if xcodebuild -project UniControl.xcodeproj -scheme UniControl -configuration Debug build 2>&1 | grep -q "BUILD SUCCEEDED"; then
        echo "✅ Build successful!"
        echo ""

        # Ask about pushing
        read -p "Push to remote? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin "$MAIN_BRANCH"
            echo "✅ Pushed to origin/$MAIN_BRANCH"
        else
            echo "⚠️  Not pushed. Run 'git push origin $MAIN_BRANCH' when ready."
        fi

        echo ""
        echo "🎉 Merge complete!"
        echo ""
        echo "Next steps:"
        echo "  1. Test the merged code: ./run-tests.sh calculator"
        echo "  2. Review changes: git log --oneline -3"
        echo "  3. If everything looks good, push: git push origin $MAIN_BRANCH"

    else
        echo "⚠️  Build failed! Check the errors above."
        echo "You may need to fix issues before pushing."
    fi

else
    echo ""
    echo "❌ Merge failed! There may be conflicts."
    echo ""
    echo "To resolve:"
    echo "  1. Fix conflicts in the files listed above"
    echo "  2. git add <resolved-files>"
    echo "  3. git commit"
    echo ""
    echo "Or to abort the merge:"
    echo "  git merge --abort"
fi

# Clean up temporary remote
git remote remove worktree 2>/dev/null || true
