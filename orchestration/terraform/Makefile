current_dir = $(shell pwd)
cluster_name ?= example## Cluster name to manage.
cluster_pem ?= ~/.ssh/ec2/us-east-1.pem## PEM file to use for ssh keys for cluster.
terraform_args ?= ## Terraform arguments.

cluster_full_pem = $(shell echo $(cluster_pem))

.PHONY: all get-lock init-terrform plan apply terraform-plan terraform-apply

default: plan

terraform-plan: # actual terraform plan command
	@echo "\033[32m==> Running terraform plan...\033[0m"
	cd cluster && terraform plan $(terraform_args) -var cluster_name=$(cluster_name) -var 
	@echo "\033[32m==> Successfully ran terraform plan!\033[0m"

terraform-apply: # actual terraform apply command
	@echo "\033[32m==> Running terraform apply...\033[0m"
	cd cluster && terraform apply $(terraform_args) -var cluster_name=$(cluster_name)
	@echo "\033[32m==> Successfully ran terraform apply!\033[0m"

terraform-destroy: # actual terraform destroy command
	@echo "\033[32m==> Running terraform destroy...\033[0m"
	cd cluster && terraform destroy -force $(terraform_args) -var cluster_name=$(cluster_name)
	@echo "\033[32m==> Successfully ran terraform destroy!\033[0m"

plan: acquire-lock init-terraform terraform-plan release-lock ## Run terraform plan step

apply: acquire-lock init-terraform create-vpc terraform-apply release-lock ## Run terraform apply step

destroy: acquire-lock init-terraform terraform-destroy release-lock ## Run terraform destroy step

configure: ## Configure nodes using ansible
	@echo "\033[32m==> Running ansible playbook...\033[0m"
	ansible-playbook --ask-vault-pass -i ../ansible/ec2.py \
          --ssh-common-args="-o StrictHostKeyChecking=no -i $(cluster_full_pem)" \
          --extra-vars "cluster_name=$(cluster_name)" -u ubuntu \
          ../ansible/playbooks/aws.yml
	@echo "\033[32m==> Successfully ran ansible playbook!\033[0m"

create-vpc: # confirm VPC is created
	@echo "\033[32m==> Confirming VPC is created...\033[0m"
	cd vpc && terraform apply $(terraform_args)
	@echo "\033[32m==> Successfully confirmed VPC is created!\033[0m"

acquire-lock: ## Acquire lock in order to safely run terraform commands on shared remote state in S3
	@echo "\033[32m==> Acquiring lock...\033[0m"
	aws configure set preview.sdb true
	aws sdb create-domain --region us-east-1 --domain-name terraform_locking
	-aws sdb put-attributes --region us-east-1 --domain-name terraform_locking \
          --item-name terraform_lock --attributes \
          Name=lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=lock,Value=free
	aws sdb put-attributes --region us-east-1 --domain-name terraform_locking \
          --item-name terraform_lock --attributes \
          Name=lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=lock,Value=`id -u -n`-`hostname`
	@echo "\033[32m==> Lock successfully acquired!\033[0m"

init-terraform: ## Initialize/reset local terraform state based on what is in S3 for cluster
	@echo "\033[32m==> Initializing terraform state with remote S3 config...\033[0m"
	cd cluster && rm -f .terraform/terraform.tfstate
	cd cluster && rm -f .terraform/terraform.tfstate.backup
	cd cluster && terraform remote config -backend=s3 -backend-config="bucket=sendence-dev" \
          -backend-config="region=us-east-1" \
          -backend-config="key=terraform-state/cluster/$(cluster_name)-terraform.tfstate"
	@echo "\033[32m==> Terraform state successfully initialized!\033[0m"

release-lock: ## Release lock after safely running terraform commands on shared remote state in S3
	@echo "\033[32m==> Releasing lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name terraform_locking \
          --item-name terraform_lock --attributes Name=lock,Value=free,Replace=true \
          --expected Name=lock,Value=`id -u -n`-`hostname`
	@echo "\033[32m==> Lock successfully released!\033[0m"

help: ## Self-documenting help command
	@echo 'Usage: make [option1=value] [option2=value,...] [target]'
	@echo ''
	@echo 'Options:'
	@grep -E '^[a-zA-Z_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "?="}; {printf "\033[36m%-30s\033[0m ##%s\n", $$1, $$2}' \
          | awk 'BEGIN {FS = "## "}; {printf "%s %s \033[36m(Default: %s)\033[0m\n", $$1, $$3, $$2}'
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

