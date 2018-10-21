# Setup

To run these python apps:

    - [create an api key](https://grafana-paas.cloudapps.digital/org/apikeys) with "Viewer" capability
    - set it in the GRAFANA_TOKEN environment variable
    - create a virtualenv if you want
    - run `pip install -r requirements.txt`

# show_queries.py

This script scrapes all the PromQL queries from Grafana and shows
them, in sorted order.

To run it:

    - run `./show_queries.py`

This directory has a `.python-version` file to be used by
[pyenv](https://github.com/pyenv/pyenv).

# find_missing_metrics.py

This script will attempt to find missing metrics on the prometheus running an older version which are being used in the Grafana.
It will show the expressions in Grafana, then the result of an API call to an older Prometheus server (could be EC2 or one deployed locally) based on the extracted metrics (boolean in the result refers to whether any metric results were returned followed by the metric) and will report any metrics without data points in the older Prometheus server but have data points in the latest prometheus server.

NB - keywords for prom QL operators used in the Grafana expressions are ignored, other wrongly identified metrics should be added to the `IGNORE_WORDS` list found at the top of the `find_missing_metrics.py` file.

To run it:

    - set the OLD_PROM_SERVER environment variable to an EC2 staging prometheus server, or a locally deployed older prometheus version
    - set the NEW_PROM_SERVER environment variable to an ECS staging prometheus server, or a locally running the latest prometheus
    - run `./find_missing_metrics.py`
