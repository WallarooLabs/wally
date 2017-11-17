ansible_parallelism ?= default## Number of machines to process in parallel for Ansible
num_leaders ?= 1## Number of leader nodes
num_followers ?= 2## Number of follower nodes
ansible_install_devtools ?= false## Install dev tools on nodes

# Make sure we have a valid value for ansible_install_devtools
ifdef ansible_install_devtools
  ifeq (,$(filter $(ansible_install_devtools),false true))
    $(error Unknown ansible_install_devtools option "$(ansible_install_devtools). \
      Valid options are 'true' and 'false'")
  endif
endif

# set arguments for # of nodes
num_leaders_arg := NUM_LEADERS=$(num_leaders)
num_followers_arg := NUM_FOLLOWERS=$(num_followers)

# set arguments for ansible parallelism
ifeq ($(ansible_parallelism),default)
  ansible_parallelism_arg := 
else
  ansible_parallelism_arg := --forks=$(ansible_parallelism)
endif

.PHONY: build configure sleep10

default: build

sleep10: # sleep 10 seconds
	@echo "\033[36m==> Sleeping 10 seconds for vagrant machines to \
 spin up...\033[0m"
	@sleep 10

cluster: build sleep10 configure ## Creates a cluster and configures it with Ansible

build: ## Run vagrant up step to create a cluster
	$(num_leaders_arg) $(num_followers_arg) vagrant up

destroy: ## Run vagrant destroy step to destroy a cluster
	$(num_leaders_arg) $(num_followers_arg) vagrant destroy -f

configure: ## Configure nodes using ansible
	@echo "\033[32m==> Running ansible playbook...\033[0m"
	$(num_leaders_arg) $(num_followers_arg) ansible-playbook \
          $(ansible_parallelism_arg) -i ../ansible/vagrant.py \
          --ssh-common-args="-o StrictHostKeyChecking=no" \
          --extra-vars "cluster_name=$(cluster_name) \
          install_devtools=$(ansible_install_devtools) " \
          ../ansible/playbooks/vagrant.yml
	@echo "\033[32m==> Successfully ran ansible playbook!\033[0m"

help: ## Self-documenting help command
	@echo 'Usage: make [option1=value] [option2=value,...] [target]'
	@echo ''
	@echo 'Options:'
	@grep -E '^[a-zA-Z_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "?="}; {printf "\033[36m%-30s\033[0m ##%s\n", $$1, $$2}'\
          | awk 'BEGIN {FS = "## "}; \
          {printf "%s %s \033[36m(Default: %s)\033[0m\n", $$1, $$3, $$2}'
	@grep -E 'filter.*arch.*\)$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-30s\033[0m %s\n", \
          "  Valid values for " $$5 ":", $$7}'
	@grep -E 'filter.*in_docker.*\)$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-30s\033[0m %s\n", \
          "  Valid values for " $$5 ":", $$7}'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", \
          $$1, $$2}'

