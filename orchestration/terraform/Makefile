current_dir = $(shell pwd)
cluster_name ?= example## Cluster name to manage.
region ?= us-east-1## Region to launch cluster in.
availability_zone ?= ## Availability Zone to launch cluster in.
cluster_pem ?= ~/.ssh/ec2/$(region).pem## PEM file to use for ssh keys for cluster.
terraform_args ?= ## Terraform arguments.
use_placement_group ?= false## Whether to use placement group or not
ansible_vault_password ?= ~/.ansible_vault_pass.txt## Ansible Vault password file
use_cheapest_instances ?= true## Find cheapest instances to use (spot included); Will automagically use placement groups if applicable
mem_required ?= 0.5## Minimum amount of memory in GB per instance (for use_cheapest_instances=true)
cpus_required ?= 0.05## Minimum amount of CPUs per instance (for use_cheapest_instances=true)
no_burst ?= false## Don't use burstable instances (t1.*, t2.*) (for use_cheapest_instances=true)
no_burst_arg :=# args for no-burst for cheapest instance script
no_spot ?= false## Don't use spot pricing (for use_cheapest_instances=true)
no_spot_arg :=# args for no-spot for cheapest instance script
spot_bid_factor ?= 1.25## Percentage of maximum historical price to bid (automagically capped at instance on-demand price) (for use_cheapest_instances=true)
force_instance ?= ## Force a specific instance type (for use_cheapest_instances=true)
ansible_parallelism ?= default## Number of machines to process in parallel for Ansible
num_leaders ?= 1## Number of leader nodes
num_followers ?= 2## Number of follower nodes

# set arguments for # of nodes
num_leaders_arg := -var leader_default_nodes=$(num_leaders) -var \
                   leader_max_nodes=$(num_leaders) -var \
                   leader_min_nodes=$(num_leaders)
num_followers_arg := -var follower_default_nodes=$(num_followers) -var \
                   follower_max_nodes=$(num_followers) -var \
                   follower_min_nodes=$(num_followers)

# set arguments for ansible parallelism
ifeq ($(ansible_parallelism),default)
  ansible_parallelism_arg :=
else
  ansible_parallelism_arg := --forks=$(ansible_parallelism)
endif

# Do not change or remove. Used as part of the cheapest_instance logic
define newline


endef

ifeq ($(no_burst),true)
  no_burst_arg := --no-burst
endif

ifeq ($(no_spot),true)
  no_spot_arg := --no-spot
endif

ifdef use_cheapest_instances
  ifeq (,$(filter $(use_cheapest_instances),false true))
    $(error Unknown use_cheapest_instances option "$(use_cheapest_instances). \
      Valid options are 'true' and 'false'")
  endif
endif

ifdef use_placement_group
  ifeq (,$(filter $(use_placement_group),false true))
    $(error Unknown use_placement_group option "$(use_placement_group). Valid \
      options are 'true' and 'false'")
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
        terraform-apply cluster setup_az_arg setup_ci_arg post_message

default: plan

terraform-plan: # actual terraform plan command
	@echo "\033[36m==> Running terraform plan for cluster '$(cluster_name)'\
 in region '$(region)'...\033[0m"
	cd cluster && terraform plan -var aws_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          aws_region=$(region) $(pg_arg) $(az_arg) $(ci_args) \
          $(num_leaders_arg) $(num_followers_arg)
	@echo "\033[36m==> Successfully ran terraform plan for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

terraform-apply: # actual terraform apply command
	@echo "\033[36m==> Running terraform apply for cluster \
'$(cluster_name)' in region '$(region)'...\033[0m"
	cd cluster && terraform apply -var aws_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          aws_region=$(region) $(pg_arg) $(az_arg) $(ci_args) \
          $(num_leaders_arg) $(num_followers_arg)
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
	ansible-playbook $(ansible_parallelism_arg) --vault-password-file $(ansible_vault_password) -i\
          ../ansible/ec2.py --ssh-common-args="-o StrictHostKeyChecking=no -i \
          $(cluster_full_pem)" --extra-vars "cluster_name=$(cluster_name) \
          aws_region=$(region)" -u ubuntu ../ansible/playbooks/aws.yml
	@echo "\033[36m==> Successfully ran ansible playbook for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

plan: acquire-lock create-vpc init-terraform setup_ci_arg setup_az_arg terraform-plan post_message release-lock ## Run terraform plan step

apply: acquire-lock create-vpc init-terraform setup_ci_arg setup_az_arg terraform-apply post_message release-lock ## Run terraform apply step

setup_ci_arg: old_price=$(shell egrep 'spot_price' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_ci_arg: old_az=$(shell egrep 'availability_zones' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | grep -v '#' | sed -e 's/.*: "\(.*\)",/\1/')
setup_ci_arg: old_type=$(shell egrep 'instance_type' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_ci_arg: old_pg=$(shell egrep 'placement_group.:' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_ci_arg: old_pg_args=$(if $(old_pg),ci_pg=is using placement groups\
       #pg_arg=-var placement_group=$(old_pg),ci_pg=is not using placement groups)
setup_ci_arg: tmp_ci_args=$(if $(filter $(use_cheapest_instances),true),$(if \
       $(old_type),ci_old_values=true#ci_inst_type=$(old_type)#$(old_pg_args)\
       #ci_inst_price=$(old_price)#ci_az=$(old_az)#availability_zone=$(old_az)\
       #ci_current_price=???#ci_args=-var leader_instance_type=$(old_type) -var \
       follower_instance_type=$(old_type) -var leader_spot_price=$(old_price) \
       -var follower_spot_price=$(old_price),$(shell\
       $(current_dir)/cheapest_instance.py --region $(region) --cpus \
       $(cpus_required) --mem $(mem_required) $(no_burst_arg) \
       --spot-bid-factor $(spot_bid_factor) --availability_zone \
       "$(availability_zone)" $(no_spot_arg) --instance_type "$(force_instance)")))
setup_ci_arg: # set up cheapest instances arg
	@echo $(if $(filter $(use_cheapest_instances),true),"\033[36m==> Using \
automagic cheapest instance logic...\033[0m",\
          "\033[36m==> Not using automagic cheapest instance logic...\033[0m")
	$(eval $(subst #,$(newline),$(tmp_ci_args)))
	@echo $(if $(filter $(use_cheapest_instances),true), $(if \
          $(ci_inst_type),,$(error Error running cheapest instance script!)))
	@echo $(if $(filter $(use_cheapest_instances),true), $(if \
        $(ci_old_values), "\033[36m==> Re-using values from existing cluster \
to not clobber it.\033[0m",),)
	@echo $(if $(filter $(use_cheapest_instances),true),"\033[36m==> \
Automagic cheapest instance logic determined instance_type='$(ci_inst_type)' \
current_price='$(ci_current_price)' bid_price='$(ci_inst_price)' and \
availability_zone='$(ci_az)' and $(ci_pg).\033[0m",)

post_message: # end of work output regarding automagic cheapest instance logic
	@echo $(if $(filter $(use_cheapest_instances),true),"\033[36m==> Used \
automagic cheapest instance logic...\033[0m",\
          "\033[36m==> Didn't use automagic cheapest instance logic...\033[0m")
	@echo $(if $(filter $(use_cheapest_instances),true), $(if \
        $(ci_old_values), "\033[36m==> Re-used values from existing cluster \
to not clobber it.\033[0m",),)
	@echo $(if $(filter $(use_cheapest_instances),true),"\033[36m==> \
Automagic cheapest instance logic determined instance_type='$(ci_inst_type)' \
current_price='$(ci_current_price)' bid_price='$(ci_inst_price)' and \
availability_zone='$(ci_az)' and $(ci_pg).\033[0m",)

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
	@echo "\033[36m==> Destroying VPC in region '$(region)'...\033[0m"
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
setup_az_arg: # set up availability zone arg
	$(if $(availability_zone),$(if $(subst -var \
          aws_subnet_id=,,$(tmp_az_arg)),,$(error Unable to look up\
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

force-release-lock: ## Force release lock (NOTE: ONLY USE IN EMERGENCY ELSE IT COULD CORRUPT TERRAFORM CACHE!!!!)
	@echo "\033[36m==> Forcing release of lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name terraform_lock --attributes \
          Name=lock,Value=free,Replace=true
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

