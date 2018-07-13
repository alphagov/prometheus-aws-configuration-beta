#!/bin/bash
#
# Check that documentation has been generated
#
sh ./tools/update-docs.sh

git diff --exit-code

if [ $? -gt 0 ]; then
  echo "The documentation isn't up to date. You should run tools/update-docs.sh and commit the results."
  exit 1
fi
