#!/usr/bin/env python

from grafana_api.grafana_api import GrafanaAPI
from bearer_auth import BearerAuth
import os, sys


def exprs_for_dashboard(dashboard):
    d = g.get('/dashboards/uid/%s' % dashboard['uid'])
    if 'panels' in d['dashboard']:
        panels = d['dashboard']['panels']
        for panel in panels:
            targets = panel.get('targets',[])
            for target in targets:
                if 'expr' in target:
                    yield (target['expr'], dashboard['title'], panel['title'])
    else:
        print('***** no panels {}'.format(dashboard['title']))


if __name__ == "__main__":
    try:
        token = os.environ['GRAFANA_TOKEN']
        g = GrafanaAPI(BearerAuth(token), 'grafana-paas.cloudapps.digital', protocol='https')
        dashboards = g.get('/search?type=dash-db')
        exprs = [expr for dashboard in dashboards for expr in exprs_for_dashboard(dashboard)]
        exprs.sort()
        for expr in exprs:
            print(expr)
    except KeyError as e:
        print('Please set the %s environment variable' % e.args[0], file=sys.stderr)
        exit(1)
