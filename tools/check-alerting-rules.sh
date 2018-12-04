#!/bin/bash
#
# Check prometheus alerting rules using promtool
#
set -e

promtool check rules ./terraform/modules/app-ecs-services/config/alerts/*.yml
