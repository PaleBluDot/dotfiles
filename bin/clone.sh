#!/bin/bash

if [ -z "$1" ]; then
    echo "waiting for the following arguments: username."
    exit 1
else
    name=$1
fi

echo "Cloning repo from $1..."

gh repo list $1 --limit 100 | while read -r repo _; do
    gh repo clone "$repo" "$repo" -- -q 2>/dev/null || (
    echo "$repo"
    cd "$repo"
    git checkout -q main 2>/dev/null || true
    git checkout -q master 2>/dev/null || true
    git pull -q
    )
done

echo "All repos from $1 are cloned!"

exit 0