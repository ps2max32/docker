#!/bin/sh
# Print the LLVM_REF of every ps2max32 repo's ps2max.deps on its default
# branch, one per line, without repeats (gh api; needs GH_TOKEN).
set -e
gh api --paginate orgs/ps2max32/repos --jq '.[] | select(.archived | not) | .full_name' |
while read -r repo; do
  gh api "repos/$repo/contents/ps2max.deps" --jq .content 2>/dev/null | base64 -d 2>/dev/null |
    sed -n 's/^LLVM_REF=\([0-9a-f]\{40\}\).*/\1/p' || true
done | sort -u
