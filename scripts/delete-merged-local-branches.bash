#!/bin/bash

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "main" ]]; then
  echo "You are not in \"main\" branch. Please change to \"main\" branch. Current branch: \"$current_branch\"";
  exit 1;
fi

branches=$(git branch --merged | egrep -v "^\*")

if [ -z "${branches}" ]; then
  echo "There is no branch to delete.";
  echo -e "Remove deleted branch from remote (git fetch --prune)? [Y/n]"
  read confirm;

  if [[ "$confirm" =~ ^(n|N)$ ]]; then
    echo "Exiting without deleting remote branches."
    exit 0;
  else
    git fetch --prune
  fi
  exit 0;
fi

echo -e "Here is the list of branches merged with your local branch:\n$branches\nDo you want to delete them? [Y/n] ";
read confirm;

if [[ "$confirm" =~ ^(n|N)$ ]]; then
    echo "Exiting without deleting any branches.";
    exit 0;
else
    echo "$branches" | xargs git branch -d;
    echo "All branches are deleted.";


    echo -e "Remove deleted branch from remote (git fetch --prune)? [Y/n]"
    read confirm;

    if [[ "$confirm" =~ ^(n|N)$ ]]; then
      echo "Exiting without deleting remote branches."
      exit 0;
    else
      git fetch --prune
    fi
fi
