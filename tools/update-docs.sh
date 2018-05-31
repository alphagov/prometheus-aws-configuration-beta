#!/bin/bash
#
# Update docs across all projects and modules
#
if [[ ! $(which terraform-docs) ]]; then
  echo "Must install terraform-docs"
  exit 1
fi

for i in $(find terraform/ -name main.tf |sed 's/\/main.tf//g'); do
  terraform-docs md $i > $i/README.md
done
