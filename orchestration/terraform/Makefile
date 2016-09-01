current_dir := $(shell pwd)
cluster_name ?= ## Cluster name to manage.
region ?= us-east-1## Region to launch cluster in.
availability_zone ?= ## Availability Zone to launch cluster in.
cluster_pem ?= ~/.ssh/ec2/$(region).pem## PEM file to use for ssh keys for cluster.
terraform_args ?= ## Terraform arguments.
use_placement_group ?= false## Whether to use placement group or not
ansible_vault_password ?= ~/.ansible_vault_pass.txt## Ansible Vault password file
use_automagic_instances ?= true## Find appropriate instances to use (spot included); Will automagically use placement groups if applicable
mem_required ?= 0.5## Minimum amount of memory in GB per instance (for use_automagic_instances=true)
cpus_required ?= 0.05## Minimum amount of CPUs per instance (for use_automagic_instances=true)
no_burst ?= false## Don't use burstable instances (t1.*, t2.*) (for use_automagic_instances=true)
no_burst_arg :=# args for no-burst for automagic instance script
no_spot ?= false## Don't use spot pricing (for use_automagic_instances=true)
no_spot_arg :=# args for no-spot for automagic instance script
spot_bid_factor ?= 1.25## Percentage of maximum historical price to bid (automagically capped at instance on-demand price) (for use_automagic_instances=true)
force_instance ?= ## Force a specific instance type (for use_automagic_instances=true)
ansible_parallelism ?= default## Number of machines to process in parallel for Ansible
num_leaders ?= ## Number of leader nodes (1 by default)
num_followers ?= ## Number of follower nodes (2 by default)
ansible_num_system_cpus ?= ## Number of cpus to dedicate for system processes (the rest are isolated for user processes)
ansible_isolcpus ?= false## Use isolcpus kernel boot param

# Make sure we have a valid value for ansible_isolcpus
ifdef ansible_isolcpus
  ifeq (,$(filter $(ansible_isolcpus),false true))
    $(error Unknown ansible_isolcpus option "$(ansible_isolcpus). \
      Valid options are 'true' and 'false'")
  endif
endif

# set arguments for ansible num_system_cpus variable
ifeq ($(ansible_num_system_cpus),)
  ansible_num_sys_cpus_arg :=
else
  ansible_num_sys_cpus_arg := num_system_cpus=$(ansible_num_system_cpus)
endif

# set arguments for ansible parallelism
ifeq ($(ansible_parallelism),default)
  ansible_parallelism_arg :=
else
  ansible_parallelism_arg := --forks=$(ansible_parallelism)
endif

# Do not change or remove. Used as part of the automagic_instance logic
define newline


endef

ifeq ($(no_burst),true)
  no_burst_arg := --no-burst
endif

ifeq ($(no_spot),true)
  no_spot_arg := --no-spot
endif

ifdef use_automagic_instances
  ifeq (,$(filter $(use_automagic_instances),false true))
    $(error Unknown use_automagic_instances option "$(use_automagic_instances). \
      Valid options are 'true' and 'false'")
  endif
endif

ifeq ($(use_automagic_instances),false)
  ifeq ($(no_burst),true)
    $(error Can't use no_burst option unless use_automagic_instances=true.)
  endif
  ifeq ($(no_spot),true)
    $(error Can't use no_spot option unless use_automagic_instances=true.)
  endif
  ifneq ($(cpus_required),0.05)
    $(error Can't use cpus_required option unless use_automagic_instances=true.)
  endif
  ifneq ($(mem_required),0.5)
    $(error Can't use mem_required option unless use_automagic_instances=true.)
  endif
  ifneq ($(spot_bid_factor),1.25)
    $(error Can't use spot_bid_factor option unless use_automagic_instances=true.)
  endif
  ifneq ($(force_instance),)
    $(error Can't use force_instance option unless use_automagic_instances=true.)
  endif
endif

ifeq ($(use_automagic_instances),true)
  ifeq ($(use_placement_group),true)
    $(error Can't use use_placement_group option when use_automagic_instances=true. \
      Automagic instance script will use placement groups if possible.)
  endif
  ifneq (,$(findstring -var leader_,$(terraform_args)))
    $(error Can't use leader_* options when use_automagic_instances=true. \
      Use force_instance instead to control instance type. The automagic \
      instance script will figure everything else out on it's own.)
  endif
  ifneq (,$(findstring -var follower_,$(terraform_args)))
    $(error Can't use follower_* options when use_automagic_instances=true. \
      Use force_instance instead to control instance type. The automagic \
      instance script will figure everything else out on it's own.)
  endif
endif

ifdef use_placement_group
  ifeq (,$(filter $(use_placement_group),false true))
    $(error Unknown use_placement_group option "$(use_placement_group). Valid \
      options are 'true' and 'false'")
  endif
endif

ifeq ($(use_placement_group),true)
  valid_instances := $(shell curl -s \
    http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html \
    | grep -o '<\(code\).*</\1>' | egrep -o '\w{2,3}\.\w{5,}' | grep -v amazon)
  ifeq (,$(findstring -var follower_instance_type=,$(terraform_args)))
    $(error Must override follower_instance_type with terraform_args when using\
      placement groups!)
  else
    follower_instance_type := $(shell echo $(terraform_args) | sed -E \
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
    leader_instance_type := $(shell echo $(terraform_args) | sed -E \
      's/.*-var leader_instance_type=([a-zA-Z0-9.-]+).*/\1/')
    ifeq (,$(findstring  $(leader_instance_type) , $(valid_instances) ))
      $(error leader_instance_type ($(leader_instance_type)) must be one of the\
        following! $(valid_instances))
    endif
  endif
  pg_arg := -var placement_group=buffy-$(cluster_name)
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

cluster_full_pem := $(shell echo $(cluster_pem))

.PHONY: all init-vpc-terraform init-terrform plan apply terraform-plan\
        terraform-apply cluster setup_az_arg setup_ci_arg post_message\
        acquire-vpc-lock release-vpc-lock acquire-cluster-lock release-vpc-lock\
        force-release-vpc-lock force-release-cluster-lock

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
          aws_region=$(region) $(pg_arg) $(az_arg) $(ci_args) \
          $(num_leaders_arg) $(num_followers_arg)
	@echo "\033[36m==> Successfully ran terraform destroy for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

sleep60: # sleep 60 seconds
	@echo "\033[36m==> Sleeping 60 seconds for cluster '$(cluster_name)' in\
 region '$(region)' to spin up...\033[0m"
	@sleep 60

cluster: in_cluster=true
cluster: check-cluster-name apply sleep60 configure ## Creates a cluster and configures it with Ansible

destroy: check-cluster-name acquire-cluster-lock init-terraform setup_ci_arg setup_az_arg terraform-destroy release-cluster-lock ## Run terraform destroy step

configure: check-cluster-name ## Configure nodes using ansible
	$(if $(wildcard $(ansible_vault_password)),,$(error Ansible Vault \
          password file ($(ansible_vault_password)) is missing!))
	@echo "\033[36m==> Running ansible playbook for cluster \
'$(cluster_name)' in region '$(region)'...\033[0m"
	ansible-playbook $(ansible_parallelism_arg) --vault-password-file \
          $(ansible_vault_password) -i \
          ../ansible/ec2.py --ssh-common-args="-o StrictHostKeyChecking=no -i \
          $(cluster_full_pem)" --extra-vars "cluster_name=$(cluster_name) \
          aws_region=$(region) isolcpus=$(ansible_isolcpus) \
          $(ansible_num_sys_cpus_arg)" -u ubuntu \
          ../ansible/playbooks/aws.yml
	@echo "\033[36m==> Successfully ran ansible playbook for cluster \
'$(cluster_name)' in region '$(region)'!\033[0m"

plan: check-cluster-name acquire-vpc-lock create-vpc release-vpc-lock acquire-cluster-lock init-terraform setup_ci_arg setup_az_arg terraform-plan post_message release-cluster-lock ## Run terraform plan step

apply: check-cluster-name acquire-vpc-lock create-vpc release-vpc-lock acquire-cluster-lock init-terraform setup_ci_arg setup_az_arg terraform-apply post_message release-cluster-lock ## Run terraform apply step (set use_automagic_instances=false to be able to change more than # instances)

setup_ci_arg: exists=$(shell egrep 'resources' \
                ./cluster/.terraform/terraform.tfstate | sort -u | sed \
                -e 's/.*: \(.*\)/\1/')
setup_ci_arg: old_num_followers=$(shell egrep -A 15 'followers' \
                ./cluster/.terraform/terraform.tfstate | grep desired_capacity \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_ci_arg: old_num_leaders=$(shell egrep -A 15 'leaders' \
                ./cluster/.terraform/terraform.tfstate | grep desired_capacity \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_ci_arg: leader_num=$(if $(num_leaders),$(num_leaders),$(old_num_leaders))
setup_ci_arg: follower_num=$(if $(num_followers),$(num_followers),$(old_num_followers))
setup_ci_arg: num_instances_args=num_leaders_arg=$(if $(leader_num),-var \
                leader_default_nodes=$(leader_num),)@num_followers_arg=$(if $(follower_num),-var \
                follower_default_nodes=$(follower_num),)
setup_ci_arg: old_price=$(shell egrep 'spot_price' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_ci_arg: old_az=$(shell egrep 'availability_zones' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | grep -v '#' | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_ci_arg: old_type=$(shell egrep 'instance_type' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_ci_arg: old_pg=$(shell egrep 'placement_group.:' \
                $(current_dir)/cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_ci_arg: old_pg_args=$(if $(old_pg),ci_pg=is using placement groups\
       #pg_arg=-var placement_group=$(old_pg),ci_pg=is not using placement groups)
setup_ci_arg: tmp_ci_args=$(if $(filter $(use_automagic_instances),true),$(if \
       $(old_type),ci_old_values=true#ci_inst_type=$(old_type)#$(old_pg_args)\
       #ci_inst_price=$(old_price)#ci_az=$(old_az)#availability_zone=$(old_az)\
       #ci_current_price=???#ci_args=-var leader_instance_type=$(old_type) -var \
       follower_instance_type=$(old_type) -var leader_spot_price=$(old_price) \
       -var follower_spot_price=$(old_price),$(shell\
       $(current_dir)/automagic_instance.py --region $(region) --cpus \
       $(cpus_required) --mem $(mem_required) $(no_burst_arg) \
       --spot-bid-factor $(spot_bid_factor) --availability_zone \
       "$(availability_zone)" $(no_spot_arg) --instance_type "$(force_instance)")))
setup_ci_arg: # set up automagic instances arg
	@echo $(if $(filter $(exists),{), $(if \
          $(in_cluster),$(error Can't create an existing cluster! Use apply \
          instead to modify it.)))
	@echo $(if $(filter $(use_automagic_instances),true),"\033[36m==> Using \
automagic instance logic...\033[0m",\
          "\033[36m==> Not using automagic instance logic...\033[0m")
	$(eval $(subst #,$(newline),$(tmp_ci_args)))
	$(eval $(subst @,$(newline),$(num_instances_args)))
	@echo $(if $(filter $(use_automagic_instances),true), $(if \
          $(ci_inst_type),,$(error Error running automagic instance script!)))
	@echo $(if $(filter $(use_automagic_instances),true), $(if \
        $(ci_old_values), "\033[36m==> Re-using values from existing cluster \
to not clobber it.\033[0m",),)
	@echo $(if $(filter $(use_automagic_instances),true),"\033[36m==> \
Automagic instance logic determined instance_type='$(ci_inst_type)' \
current_price='$(ci_current_price)' bid_price='$(ci_inst_price)' and \
availability_zone='$(ci_az)' and $(ci_pg).\033[0m",)

post_message: # end of work output regarding automagic instance logic
	@echo $(if $(filter $(use_automagic_instances),true),"\033[36m==> Used \
automagic instance logic...\033[0m",\
          "\033[36m==> Didn't use automagic instance logic...\033[0m")
	@echo $(if $(filter $(use_automagic_instances),true), $(if \
        $(ci_old_values), "\033[36m==> Re-used values from existing cluster \
to not clobber it.\033[0m",),)
	@echo $(if $(filter $(use_automagic_instances),true),"\033[36m==> \
Automagic instance logic determined instance_type='$(ci_inst_type)' \
current_price='$(ci_current_price)' bid_price='$(ci_inst_price)' and \
availability_zone='$(ci_az)' and $(ci_pg).\033[0m",)

create-vpc: check-cluster-name init-vpc-terraform # confirm VPC is created
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

destroy-vpc: check-cluster-name init-vpc-terraform # destroy VPC in region
	@echo "\033[36m==> Destroying VPC in region '$(region)'...\033[0m"
	cd vpc && terraform destroy -force $(terraform_args) -var \
          aws_region=$(region)
	@echo "\033[36m==> Successfully confirmed VPC is created in region \
'$(region)'!\033[0m"

acquire-cluster-lock: check-cluster-name ## Acquire cluster lock in order to safely run terraform commands on shared remote state in S3
	@echo "\033[36m==> Acquiring cluster lock...\033[0m"
	aws configure set preview.sdb true
	aws sdb create-domain --region us-east-1 --domain-name terraform_locking
        # create lock item if needed
	-aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=free,Replace=true \
          --expected Name=$(cluster_name)-lock,Exists=false
        # get a free lock
	-aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=$(cluster_name)-lock,Value=free
        # next command is for when a previous make target failed without releasing a lock
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> Cluster lock successfully acquired!\033[0m"

acquire-vpc-lock: check-cluster-name ## Acquire vpc lock in order to safely run terraform commands on shared remote state in S3
	@echo "\033[36m==> Acquiring vpc lock...\033[0m"
	aws configure set preview.sdb true
	aws sdb create-domain --region us-east-1 --domain-name terraform_locking
        # create lock item if needed
	-aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=vpc-lock,Value=free,Replace=true \
          --expected Name=vpc-lock,Exists=false
        # get a free lock
	-aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=vpc-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=vpc-lock,Value=free
        # next command is for when a previous make target failed without releasing a lock
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=vpc-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=vpc-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> VPC lock successfully acquired!\033[0m"

check-cluster-name: # check for valid cluster name
	$(if $(cluster_name),,$(error 'cluster_name' cannot be empty!))

init-vpc-terraform: check-cluster-name ## Initialize/reset local terraform state based on what is in S3 for vpc
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
                'Subnets[*].{SubnetId:SubnetId}' --output text | head -n 1),)
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

release-cluster-lock: check-cluster-name ## Release cluster lock after safely running terraform commands on shared remote state in S3
	@echo "\033[36m==> Releasing cluster lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=free,Replace=true \
          --expected Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> Cluster lock successfully released!\033[0m"

force-release-cluster-lock: check-cluster-name ## Force release cluster lock (NOTE: ONLY USE IN EMERGENCY ELSE IT COULD CORRUPT TERRAFORM CACHE!!!!)
	@echo "\033[36m==> Forcing release of cluster lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=free,Replace=true
	@echo "\033[36m==> Cluster lock successfully released!\033[0m"

release-vpc-lock: check-cluster-name ## Release vpc lock after safely running terraform commands on shared remote state in S3
	@echo "\033[36m==> Releasing vpc lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=vpc-lock,Value=free,Replace=true \
          --expected Name=vpc-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> VPC lock successfully released!\033[0m"

force-release-vpc-lock: check-cluster-name ## Force release vpc lock (NOTE: ONLY USE IN EMERGENCY ELSE IT COULD CORRUPT TERRAFORM CACHE!!!!)
	@echo "\033[36m==> Forcing release of vpc lock...\033[0m"
	aws sdb put-attributes --region us-east-1 --domain-name \
          terraform_locking --item-name $(region)_lock --attributes \
          Name=vpc-lock,Value=free,Replace=true
	@echo "\033[36m==> VPC lock successfully released!\033[0m"

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
	@echo "\033[31mUse by adding '-var <VAR1_NAME>=<VALUE1> -var \
<VAR2_NAME>=<VALUE2>' to terraform_args.\033[0m"
	@echo "\033[31mCannot use leader_* and follower_* with \
use_automagic_instances=true.\033[0m"
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", \
          $$1, $$2}'

