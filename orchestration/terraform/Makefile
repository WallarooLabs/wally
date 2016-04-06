current_dir = $(shell pwd)
cluster_name ?= example## Cluster name to manage.
region ?= us-east-1## Region to launch cluster in.
availability_zone ?= ## Availability Zone to launch cluster in.
cluster_pem ?= ~/.ssh/ec2/$(region).pem## PEM file to use for ssh keys for cluster.
terraform_args ?= ## Terraform arguments.
use_placement_group ?= false## Whether to use placement group or not
ansible_vault_password ?= ~/.ansible_vault_pass.txt## Ansible Vault password file

ifdef use_placement_group
  ifeq (,$(filter $(use_placement_group),false true))
    $(error Unknown use_placement_group option "$(use_placement_group)")
  endif
endif

ifeq ($(use_placement_group),true)
  valid_instances = $(shell curl -s \
    http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html \
    | grep -o '<\(code\).*</\1>' | egrep -o '\w{2,3}\.\w{5,}' | grep -v amazon)
  ifeq (,$(findstring -var follower_instance_type=,$(terraform_args)))
    $(error Must override follower_instance_type with terraform_args when using\
      placement groups!)
  else
    follower_instance_type = $(shell echo $(terraform_args) | sed -E \
      's/.*-var follower_instance_type=([a-zA-Z0-9.-]+).*/\1/')
    ifeq (,$(findstring  $(follower_instance_type) , $(valid_instances) ))
      $(error follower_instance_type ($(follower_instance_type)) must be one of\
        the following! $(valid_instances))
    endif
  endif
  ifeq (,$(findstring -var leader_instance_type=,$(terraform_args)))
    $(error Must override leader_instance_type with terraform_args when using \
      placement groups!)
  else
    leader_instance_type = $(shell echo $(terraform_args) | sed -E \
      's/.*-var leader_instance_type=([a-zA-Z0-9.-]+).*/\1/')
    ifeq (,$(findstring  $(leader_instance_type) , $(valid_instances) ))
      $(error leader_instance_type ($(leader_instance_type)) must be one of the\
        following! $(valid_instances))
    endif
  endif
  pg_arg = -var placement_group=buffy-$(cluster_name)
endif

ifneq (,$(findstring -var leader_spot_price=,$(terraform_args)))
  ifeq (,$(findstring -var leader_instance_type=,$(terraform_args)))
    $(error Must override leader_instance_type with terraform_args when using \
      Spot Pricing!)
  else
    ifneq (,$(findstring -var leader_instance_type=t2.,$(terraform_args)))
      $(error leader_instance_type cannot be T2.* when using Spot Pricing!)
    endif
    ifneq (,$(findstring -var leader_instance_type=hs1.,$(terraform_args)))
      $(error leader_instance_type cannot be HS1.* when using Spot Pricing!)
    endif
  endif
endif

ifneq (,$(findstring -var follower_spot_price=,$(terraform_args)))
  ifeq (,$(findstring -var follower_instance_type=,$(terraform_args)))
    $(error Must override follower_instance_type with terraform_args when using\
      Spot Pricing!)
  else
    ifneq (,$(findstring -var follower_instance_type=t2.,$(terraform_args)))
      $(error follower_instance_type cannot be T2.* when using Spot Pricing!)
    endif
    ifneq (,$(findstring -var follower_instance_type=hs1.,$(terraform_args)))
      $(error follower_instance_type cannot be HS1.* when using Spot Pricing!)
    endif
  endif
endif

cluster_full_pem = $(shell echo $(cluster_pem))

.PHONY: all get-lock init-vpc-terraform init-terrform plan apply terraform-plan\
        terraform-apply cluster setup_az_arg

default: plan

terraform-plan: # actual terraform plan command
	@echo "\033[36m==> Running terraform plan for cluster '$(cluster_name)'\
 in region '$(region)'...\033[0m"
	cd cluster && terraform plan -var aws_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          aws_region=$(region) $(pg_arg) $(az_arg)
	@echo "\033[36m==> Successfully ran terraform plan for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

terraform-apply: # actual terraform apply command
	@echo "\033[36m==> Running terraform apply for cluster \
'$(cluster_name)' in region '$(region)'...\033[0m"
	cd cluster && terraform apply -var aws_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          aws_region=$(region) $(pg_arg) $(az_arg)
	@echo "\033[36m==> Successfully ran terraform apply for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

terraform-destroy: # actual terraform destroy command
	@echo "\033[36m==> Running terraform destroy for cluster \
'$(cluster_name)' in region '$(region)'...\033[0m"
	cd cluster && terraform destroy -force -var aws_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          aws_region=$(region) $(pg_arg) $(az_arg)
	@echo "\033[36m==> Successfully ran terraform destroy for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

sleep60: # sleep 60 seconds
	@echo "\033[36m==> Sleeping 60 seconds for cluster '$(cluster_name)' in\
 region '$(region)' to spin up...\033[0m"
	@sleep 60

cluster: apply sleep60 configure ## Creates a cluster and configures it with Ansible

destroy: acquire-lock setup_az_arg init-terraform terraform-destroy release-lock ## Run terraform destroy step

configure: ## Configure nodes using ansible
	$(if $(wildcard $(ansible_vault_password)),,$(error Ansible Vault \
          password file ($(ansible_vault_password)) is missing!))
	@echo "\033[36m==> Running ansible playbook for cluster \
'$(cluster_name)' in region '$(region)'...\033[0m"
	ansible-playbook --vault-password-file $(ansible_vault_password) -i\
          ../ansible/ec2.py --ssh-common-args="-o StrictHostKeyChecking=no -i \
          $(cluster_full_pem)" --extra-vars "cluster_name=$(cluster_name) \
          aws_region=$(region)" -u ubuntu ../ansible/playbooks/aws.yml
	@echo "\033[36m==> Successfully ran ansible playbook for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

plan: acquire-lock create-vpc setup_az_arg init-terraform terraform-plan release-lock ## Run terraform plan step

apply: acquire-lock create-vpc setup_az_arg init-terraform terraform-apply release-lock ## Run terraform apply step

create-vpc: init-vpc-terraform # confirm VPC is created
	@echo "\033[36m==> Confirming VPC is created in region \
'$(region)'...\033[0m"
	cd vpc && terraform apply $(terraform_args) -var aws_region=$(region) \
          $(shell aws ec2 --region $(region) describe-availability-zones \
          --query 'AvailabilityZones[*].ZoneName' --output text | awk \
          'function f(v) {return v == 0 ? 2: (v < 0 ? -v : v)} {print \
          "-var aws_availability_zone_1=" $$(f(NF - 0)) \
          " -var aws_availability_zone_2=" $$(f(NF - 1)) \
          " -var aws_availability_zone_3=" $$(f(NF - 2)) \
          " -var aws_availability_zone_4=" $$(f(NF - 3))}')
	@echo "\033[36m==> Successfully confirmed VPC is created in region \
'$(region)'!\033[0m"

destroy-vpc: init-vpc-terraform # destroy VPC in region
	@echo "\033[36m==> Destorying VPC in region '$(region)'...\033[0m"
	cd vpc && terraform destroy -force $(terraform_args) -var \
          aws_region=$(region)
	@echo "\033[36m==> Successfully confirmed VPC is created in region \
'$(region)'!\033[0m"

acquire-lock: ## Acquire lock in order to safely run terraform commands on shared remote state in S3
	@echo "\033[36m==> Acquiring lock...\033[0m"
	aws configure set preview.sdb true
	aws sdb create-domain --region us-east-1 --domain-name terraform_locking
	-aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name terraform_lock --attributes \
          Name=lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=lock,Value=free
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name terraform_lock --attributes \
          Name=lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> Lock successfully acquired!\033[0m"

init-vpc-terraform: ## Initialize/reset local terraform state based on what is in S3 for vpc
	@echo "\033[36m==> Initializing terraform state for VPC in region \
'$(region)' with remote S3 config...\033[0m"
	cd vpc && rm -f .terraform/terraform.tfstate
	cd vpc && rm -f .terraform/terraform.tfstate.backup
	cd vpc && terraform remote config -backend=s3 \
          -backend-config="bucket=sendence-dev" \
          -backend-config="region=us-east-1" \
          -backend-config="key=terraform-state/vpc/$(region)-terraform.tfstate"
	@echo "\033[36m==> Terraform state successfully initialized for VPC in \
region '$(region)'!\033[0m"

setup_az_arg: tmp_az_arg=$(if $(availability_zone),-var aws_subnet_id=$(shell \
                aws ec2 --region $(region) describe-subnets --filters \
                Name=availabilityZone,Values=$(availability_zone) \
                Name=tag:Project,Values=buffy --query \
                'Subnets[*].{SubnetId:SubnetId}' --output text),)
setup_az_arg: # set up az arg
	$(if $(availability_zone),$(if $(subst -var \
          aws_subnet_id=,,$(tmp_az_arg)),@echo "blah",$(error Unable to look up\
          subnet for AZ $(availability_zone) in region $(region)!)),)
	$(eval az_arg=$(tmp_az_arg))

init-terraform: ## Initialize/reset local terraform state based on what is in S3 for cluster
	@echo "\033[36m==> Initializing terraform state for cluster \
'$(cluster_name)' in region '$(region)' with remote S3 config...\033[0m"
	cd cluster && rm -f .terraform/terraform.tfstate
	cd cluster && rm -f .terraform/terraform.tfstate.backup
	cd cluster && terraform remote config -backend=s3 \
          -backend-config="bucket=sendence-dev" \
          -backend-config="region=us-east-1" \
          -backend-config="key=terraform-state/cluster/$(region)-$(cluster_name)-terraform.tfstate"
	@echo "\033[36m==> Terraform state successfully initialized for cluster\
 '$(cluster_name)' in region '$(region)'!\033[0m"

release-lock: ## Release lock after safely running terraform commands on shared remote state in S3
	@echo "\033[36m==> Releasing lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name terraform_lock --attributes \
          Name=lock,Value=free,Replace=true \
          --expected Name=lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> Lock successfully released!\033[0m"

help: ## Self-documenting help command
	@echo 'Usage: make [option1=value] [option2=value,...] [target]'
	@echo ''
	@echo 'Options:'
	@grep -E '^[a-zA-Z_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "?="}; {printf "\033[36m%-30s\033[0m ##%s\n", $$1, $$2}'\
          | awk 'BEGIN {FS = "## "}; {printf \
          "%s %s \033[36m(Default: %s)\033[0m\n", $$1, $$3, $$2}'
	@grep -E 'filter.*arch.*\)$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-30s\033[0m %s\n", \
          "  Valid values for " $$5 ":", $$7}'
	@grep -E 'filter.*in_docker.*\)$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-30s\033[0m %s\n", \
          "  Valid values for " $$5 ":", $$7}'
	@echo ''
	@echo 'Terraform Variables:'
	@grep -o '"[^"]*"' $(current_dir)/cluster/variables.tf | tr '\n' ' ' \
          | grep -o '"[^"]*" "[^"]*" "[^"]*"' | grep -v cluster_name | grep -v \
          subnet_id | grep -v placement_group | grep -v project_tag | grep -v \
          aws_region | grep -v ami | awk -F\" '{printf \
          "\033[36m%-30s\033[0m %s \033[36m(Default: %s)\033[0m\n", $$2, $$4, \
          $$6}'
	@echo 'Use by adding "-var <VAR1_NAME>=<VALUE1> -var \
<VAR2_NAME>=<VALUE2>" to terraform_args.'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", \
          $$1, $$2}'

