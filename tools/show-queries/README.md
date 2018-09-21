# show_queries.py

This script scrapes all the PromQL queries from Grafana and shows
them, in sorted order.

To run it:

    - [create an api key](https://grafana-paas.cloudapps.digital/org/apikeys) with "Viewer" capability
    - set it in the GRAFANA_TOKEN environment variable
    - create a virtualenv if you want
    - run `pip install -r requirements.txt`
    - run `./show_queries.py`

This directory has a `.python-version` file to be used by
[pyenv](https://github.com/pyenv/pyenv).
