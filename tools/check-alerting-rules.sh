#!/bin/bash
#
# Check prometheus alerting rules using promtool
#
set -e

promtool check rules ./terraform/modules/prom-ec2/alerts-config/alerts/*.yml
