#!/usr/bin/env python
import json
import os
import re
import requests
import sys
import yaml

from bearer_auth import BearerAuth
from grafana_api.grafana_api import GrafanaAPI

IGNORE_WORDS = [
    "and",
    "avg",
    "avg_over_time",
    "by",
    "count",
    "deriv",
    "exported_instance",
    "ignoring",
    "increase",
    "irate",
    "job",
    "le",
    "max",
    "on",
    "or",
    "rate",
    "sort",
    "sum",
    "time",
    "topk",
    "without",
]


def exprs_for_dashboard(dashboard):
    d = g.get('/dashboards/uid/%s' % dashboard['uid'])
    if 'panels' in d['dashboard']:
        panels = d['dashboard']['panels']
        for panel in panels:
            targets = panel.get('targets', [])
            for target in targets:
                if 'expr' in target:
                    yield {
                        "expr": target['expr'],
                        "dashboard_title": dashboard['title'],
                        "panel_title": panel['title']
                    }


def exprs_for_alerts():
    exprs = []
    for yml_file in [f for f in os.listdir(os.environ.get("ALERTS_DIR")) if re.match(r'.*\.yml', f)]:
        with open("{}/{}".format(os.environ.get("ALERTS_DIR"), yml_file), 'r') as stream:
            try:
                alerts = yaml.load(stream)
                
            except yaml.YAMLError as exc:
                print(exc)

        for rule in alerts["groups"][0]['rules']:
            exprs.append({'expr': rule['expr']})

    return exprs


# remove unwanted parts of the expression
def rationalise_expr(expr, pattern, replace="%s"):
    matched = re.findall(pattern, expr)

    if matched:
        for m in matched:
            expr = expr.replace(replace % m, "")

    return expr


def extract_words_from_expressions(exprs):
    index = 0
    words = []

    print('**** Expressions:')
    for e in exprs:
        expr = e['expr']

        if len(expr) > 0:
            print(index, expr)

            expr = rationalise_expr(expr, r'\{([^}]+)', "{%s}")  # filters
            expr = rationalise_expr(expr, r'\[([^]]+)', "[%s]")  # time ranges
            expr = rationalise_expr(expr, r'\$[_\w]+')  # grafana vars
            expr = rationalise_expr(expr, r'\([a-z]+\)')  # labels

            matched_words = re.findall(r'[^\d\W]+', expr)
            words.extend(matched_words)

            index += 1

    return words


def check_metric_exists_for_word(words):
    index = 0
    missing_metric = []
    print('**** Metrics evaluation:')
    for w in set(words).difference(IGNORE_WORDS):
        r_old = requests.get("{}/api/v1/query?query={}".format(os.environ.get("OLD_PROM_SERVER"), w))
        resp_old = json.loads(r_old.content)

        if resp_old['status'] == 'success':
            print('{}: {}, {}'.format(index, len(resp_old['data']['result']) > 0, w))

            # if old prometheus server doesn't have the metric then check if new prometheus server has the metric
            if not len(resp_old['data']['result']):
                r_new = requests.get("{}/api/v1/query?query={}".format(os.environ.get("NEW_PROM_SERVER"), w))
                resp_new = json.loads(r_new.content)
                # only report it as missing if metrics are found on the new prometheus server
                if len(resp_new['data']['result']) > 0:
                    missing_metric.append(w)
        else:
            print("{}: *** {} - {}".format(index, w, resp_old))

        index += 1

    return missing_metric


if __name__ == "__main__":
    try:
        token = os.environ['GRAFANA_TOKEN']
        g = GrafanaAPI(BearerAuth(token), 'grafana-paas.cloudapps.digital', protocol='https')
        dashboards = g.get('/search?type=dash-db')
        exprs = [expr for dashboard in dashboards for expr in exprs_for_dashboard(dashboard)]
        exprs.sort(key=lambda e: e['dashboard_title'] + e['panel_title'])

        exprs.extend(exprs_for_alerts())

        words = extract_words_from_expressions(exprs)

        missing_metric = check_metric_exists_for_word(words)

        print('**** Missing metrics:' if missing_metric else '**** No missing metrics')
        for m in missing_metric:
            print(m)

    except KeyError as e:
        print('Please set the %s environment variable' % e.args[0], file=sys.stderr)
        exit(1)
