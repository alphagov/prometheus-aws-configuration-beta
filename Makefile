.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help
help:
	@cat $(MAKEFILE_LIST) | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: create-stack
create-stack: ## Create the terraform stack env vars
	. ./setup.sh -s

.PHONY: clean
clean: ## Remove all terraform state files
	. ./setup.sh -c

.PHONY: create-bucket
create-bucket: ## Create the terraform state bucket
	. ./setup.sh -b

.PHONY: init
init: ## Initialise terraform
	. ./setup.sh -i

.PHONY: plan
plan:  ## Plan all terraform
	. ./setup.sh -p

.PHONY: apply
apply: ## Apply all terraform, auto approves
	. ./setup.sh -a

.PHONY: destroy
destroy: ## Destroy stack
	. ./setup.sh -d

.PHONY: clean-single
clean-single: ## Clean terraform state for a project, make clean-single project=<project name>
	. ./setup.sh -c ${project}

.PHONY: init-single
init-single: ## Init terraform for a project, make init-single project=<project name>
	. ./setup.sh -i ${project}

.PHONY: plan-single
plan-single: ## Plan terraform for a project, make plan-single project=<project name>
	. ./setup.sh -p ${project}

.PHONY: apply-single
apply-single: ## Apply terraform for a project, make apply-single project=<project name>
	. ./setup.sh -a ${project}

.PHONY: destroy-single
destroy-single: ## Destroy terraform for a project, make destroy-single project=<project name>
	. ./setup.sh -d ${project}

.PHONY: init-list
init-list: ## Init terraform for a list of projects, make init-list list="<comma separated list of projects>"
	. ./setup.sh -i list ${list}

.PHONY: apply-list
apply-list: ## Apply terraform for a list of projects, make apply-list list="<comma separated list of projects>"
	. ./setup.sh -a list ${list}

.PHONY: destroy-list
destroy-list: ## Destroy terraform for a list of projects, make destroy-list list="<comma separated list of projects>"
	. ./setup.sh -d list ${list}

.PHONY: taint
taint: ## Taint a resource, make taint project=<project name> resource=<resource name>
	. ./setup.sh -t ${project} ${resource}

.PHONY: jump
jump: ## Jump onto the first instance on a dev environment
	. ./setup.sh -j

.PHONY: docs
docs: ## Update all terraform docs
	. ./tools/update-docs.sh
