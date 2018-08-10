#!/bin/bash
#
# Check prometheus alerting rules using promtool
#
promtool check rules ./terraform/projects/app-ecs-services/config/alerts/*

if [ $? -gt 0 ]; then
  echo "There is an error in the alerting rules"
  exit 1
fi
