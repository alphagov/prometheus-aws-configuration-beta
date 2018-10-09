echo "Usage: <arg = team name, eg observe> | no args to run all alert tests"

# find the matching team alerts or all the alerts test files
TEAM="$1"
if [ -z "${1}" ] ; then
    TEAM="*"
fi

ALERTS_PATH="./terraform/projects/app-ecs-services/config/alerts-tests"
ALERTS_DIR=($(find $ALERTS_PATH -name test-$TEAM-alerts.yml -not -name 'test-template.yml'))

# run promtool test against each alerts test file found
for ALERTS_TEST in "${ALERTS_DIR[@]}"; do
    promtool test rules $ALERTS_TEST
done
