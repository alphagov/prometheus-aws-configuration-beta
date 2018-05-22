.DEFAULT_GOAL := help
SHELL := /bin/zsh
DATE = $(shell date +%Y-%m-%d:%H:%M:%S)

.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: source_env
source_env: ## Source environment.sh
	. ./environment.sh

.PHONY: create-stack
create-stack: source_env ## Create the terraform stack env vars
	. ./setup.sh -s

.PHONY: clean
clean: ## Remove all terraform state files
	. ./setup.sh -c

.PHONY: create-bucket
create-bucket: source_env ## Create the terraform state bucket
	. ./setup.sh -b
	
.PHONY: init
init: source_env ## Initialise terraform
	. ./setup.sh -i

.PHONY: plan
plan: source_env ## Plan all terraform
	. ./setup.sh -p

.PHONY: apply
apply: source_env ## Apply all terraform, auto approves
	. ./setup.sh -a

.PHONY: apply-single
apply-single: source_env ## Apply terraform to a project, make apply-single project=<project name>
	. ./setup.sh -a ${project}

.PHONY: destroy
destroy: ## Destroy stack
	. ./setup.sh -d
