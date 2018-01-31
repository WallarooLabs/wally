current_dir := $(shell pwd)
cluster_name ?= ## Cluster name to manage.
cluster_project_name ?= wallaroo## Project name to assign as a tag to the cluster.
provider ?= aws## Provider to launch cluster in (aws, packet).
region ?= us-east-1## Region to launch cluster in. For Packet: ewr1==New York, sjc1==San Jose,CA, ams1==Amsterdam
availability_zone ?= ## Availability Zone to launch cluster in.
cluster_pem ?= ~/.ssh/ec2/$(region).pem## PEM file to use for ssh keys for cluster.
terraform_args ?= ## Terraform arguments.
terraform_locking_aws_region ?= us-east-1## AWS Region for storing terraform state
terraform_state_aws_region ?= us-east-1## AWS Region for storing terraform state
terraform_state_aws_bucket ?= sendence-dev## AWS Bucket for storing terraform state
use_placement_group ?= false## Whether to use placement group or not
terraform_packet_vars ?= ~/.terraform_packet_vars## Terraform variables for Packet
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
ansible_system_cpus ?= ## Number of cpus to dedicate for system processes (the rest are isolated for user processes)
ansible_isolcpus ?= false## Use isolcpus kernel boot param
ansible_install_devtools ?= false## Install dev tools on nodes
ansible_raid_level ?= 0## raid level for ansible for local instance store ssds
ansible_raid_fs ?= ext4## raid filesystem for ansible for local instance store ssds
ptpd_offset_max ?= 0.00025## ptpd offset tolerance beyond which things care considered out of sync (default is 250 microseconds)

inventory_script := ec2.py
ansible_user := ubuntu
all_instances := 'tag_Project_$(cluster_project_name):&tag_ClusterName_$(cluster_name):&$(region)'
follower_instances := 'tag_Project_$(cluster_project_name):&tag_ClusterName_$(cluster_name):&tag_Role_follower:&$(region)'

# if debug shell command output requested
ifdef DEBUG_SHELL
 SHELL = /bin/sh -x
endif

ansible_version := $(shell ansible --version | grep ansible | awk '{print $$2}')
ansible_required := 2.1.1.0

# check ansible version
ifneq ($(ansible_required),$(ansible_version))
  $(error Ansible version '$(ansible_required)' required! Your ansible version is '$(ansible_version)'.)
endif

terraform_version := $(shell terraform --version | head -n 1 | grep -i terraform | awk '{print $$2}')
terraform_required := v0.7.4

# check terraform version
ifneq ($(terraform_required),$(terraform_version))
  $(error Terraform version '$(terraform_required)' required! Your terraform version is '$(terraform_version)'.)
endif

# Make sure we have a valid value for provider
ifdef provider
  ifeq (,$(filter $(provider),aws packet))
    $(error Unknown provider option "$(provider). \
      Valid options are 'aws' and 'packet'")
  endif
endif

ifneq (,$(filter $(provider),packet))
  ifeq (,$(wildcard $(terraform_packet_vars)))
    $(error Terraform Packet \
          variable file ($(terraform_packet_vars)) is missing!)
  endif
  ifeq (,$(filter $(region),ewr1 sjc1 ams1))
    $(error Invalid Packet \
          region ($(region))! Valid regions are: ewr1==New York, sjc1==San Jose,CA, ams1==Amsterdam)
  endif
  packet_api_key=$(shell grep packet_api_key $(terraform_packet_vars) | awk '{print $$3}' | tr -d '"')
  packet_vars=-var-file $(terraform_packet_vars)
  cluster_pem := ~/.ssh/ec2/us-east-1.pem
  inventory_script := packet_net.py
  ansible_user := root
  all_instances := 'tag_$(cluster_project_name):&tag_Cluster_$(cluster_name):&$(region)'
  follower_instances := 'tag_$(cluster_project_name):&tag_ClusterName_$(cluster_name):&tag_Role_follower:&$(region)'
endif


# Make sure we have a valid value for ansible_isolcpus
ifdef ansible_isolcpus
  ifeq (,$(filter $(ansible_isolcpus),false true))
    $(error Unknown ansible_isolcpus option "$(ansible_isolcpus). \
      Valid options are 'true' and 'false'")
  endif
endif

# Make sure we have a valid value for ansible_install_devtools
ifdef ansible_install_devtools
  ifeq (,$(filter $(ansible_install_devtools),false true))
    $(error Unknown ansible_install_devtools option "$(ansible_install_devtools). \
      Valid options are 'true' and 'false'")
  endif
endif

# set arguments for ansible raid_level variable
ifeq ($(ansible_raid_level),)
  ansible_raid_level_arg :=
else
  ansible_raid_level_arg := raid_level=$(ansible_raid_level)
endif

# set arguments for ansible system_cpus variable
ifeq ($(ansible_raid_fs),)
  ansible_raid_fs_arg :=
else
  ansible_raid_fs_arg := raid_fs=$(ansible_raid_fs)
endif

# set arguments for ansible system_cpus variable
ifeq ($(ansible_system_cpus),)
  ansible_sys_cpus_arg :=
else
  ansible_sys_cpus_arg := system_cpus=$(ansible_system_cpus)
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
    ifeq (,$(filter $(provider),packet))
      $(error Can't use force_instance option unless use_automagic_instances=true or provider=packet.)
    endif
  endif
endif

ifeq ($(use_automagic_instances),true)
  ifneq ($(provider),aws)
    $(error Can't use use_automagic_instances=true unless using provider=aws.)
  endif
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
  ifneq ($(provider),aws)
    $(error Can't use use_placement_group=true unless using provider=aws.)
  endif
  valid_instances := $(shell curl -s \
    https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html \
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
  pg_arg := -var placement_group=wallaroo-$(cluster_name)
endif

ifneq (,$(findstring -var leader_spot_price=,$(terraform_args)))
  ifneq ($(provider),aws)
    $(error Can't use spot pricing unless using provider=aws.)
  endif
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
  ifneq ($(provider),aws)
    $(error Can't use spot pricing unless using provider=aws.)
  endif
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
        terraform-apply cluster setup_aws_az_arg setup_aws_ci_arg post_message\
        acquire-vpc-lock release-vpc-lock acquire-cluster-lock release-vpc-lock\
        force-release-vpc-lock force-release-cluster-lock setup_packet_az_arg \
        setup_packet_ci_arg

default: plan

terraform-plan: # actual terraform plan command
	@echo "\033[36m==> Running terraform plan for cluster '$(cluster_name)'\
 in region '$(region)' at provider '$(provider)'...\033[0m"
	cd $(provider)-cluster && terraform plan -var $(provider)_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          project_tag=$(cluster_project_name) -var \
          $(provider)_region=$(region) $(pg_arg) $(az_arg) $(ci_args) \
          $(num_leaders_arg) $(num_followers_arg) $(packet_vars)
	@echo "\033[36m==> Successfully ran terraform plan for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'!\033[0m"

terraform-apply: # actual terraform apply command
	@echo "\033[36m==> Running terraform apply for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	cd $(provider)-cluster && terraform apply -var $(provider)_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          project_tag=$(cluster_project_name) -var \
          $(provider)_region=$(region) $(pg_arg) $(az_arg) $(ci_args) \
          $(num_leaders_arg) $(num_followers_arg) $(packet_vars)
	@echo "\033[36m==> Successfully ran terraform apply for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'!\033[0m"

terraform-destroy: # actual terraform destroy command
	@echo "\033[36m==> Running terraform destroy for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	cd $(provider)-cluster && terraform destroy -force -var $(provider)_key_name=$(region) \
          $(terraform_args) -var cluster_name=$(cluster_name) -var \
          project_tag=$(cluster_project_name) -var \
          $(provider)_region=$(region) $(pg_arg) $(az_arg) $(ci_args) \
          $(num_leaders_arg) $(num_followers_arg) $(packet_vars)
	@echo "\033[36m==> Successfully ran terraform destroy for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'!\033[0m"

sleep60: # sleep 60 seconds
	@echo "\033[36m==> Sleeping 60 seconds for cluster '$(cluster_name)' in\
 region '$(region)' at provider '$(provider)' to spin up...\033[0m"
	@sleep 60

cluster: in_cluster=true
cluster: check-cluster-name apply sleep60 configure ## Creates a cluster and configures it with Ansible

destroy: check-cluster-name acquire-cluster-lock init-terraform setup_$(provider)_ci_arg setup_$(provider)_az_arg terraform-destroy release-cluster-lock ## Run terraform destroy step

check-ptpd-offsets: check-cluster-name ## Check ptpd offsets for all followers in the cluster
	@echo "\033[36m==> Running ansible ptpd check for followers in cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	@echo "\033[36m==> Using '$(ptpd_offset_max)' as maximum offset allowed.\033[0m"
	@echo "\033[36m==> NOTE: Use 'ptpd_offset_max=<offset>' to change.\033[0m"
	PACKET_NET_API_KEY=$(packet_api_key) ansible $(follower_instances) \
          -i ../ansible/$(inventory_script) --ssh-common-args="-o StrictHostKeyChecking=no \
          -i  $(cluster_full_pem)"  -u $(ansible_user) -m shell -a \
          'tail -n 1 /var/log/ptpd-stats.log | awk -F\, '"'"'{if (length($$6) > 0 && \
           ($$6 > $(ptpd_offset_max) || $$6 < -$(ptpd_offset_max))) {print $$6; exit 1}}'"'"
	@echo "\033[36m==> Successfully ran ansible ptpd check for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	@echo "\033[36m==> All followers are currently within offset tolerance of '$(ptpd_offset_max)'.\033[0m"

test-ansible-connection: check-cluster-name ## Check ansible connectivity/authentication with servers
	@echo "\033[36m==> Running ansible connectivity/authentication check for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	PACKET_NET_API_KEY=$(packet_api_key) ansible $(all_instances) \
          -i ../ansible/$(inventory_script) --ssh-common-args="-o StrictHostKeyChecking=no \
          -i  $(cluster_full_pem)"  -u $(ansible_user) -m raw -a "hostname -A"
	@echo "\033[36m==> Successfully ran ansible connectivity/authentication check for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"

sync-wallaroo: check-cluster-name ## Rsync wallaroo repo to nodes
	@echo "\033[36m==> Running ansible to rsync wallaroo repo to cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	PACKET_NET_API_KEY=$(packet_api_key) ansible $(all_instances) \
          -i ../ansible/$(inventory_script) --ssh-common-args="-o StrictHostKeyChecking=no \
          -i  $(cluster_full_pem)"  -u $(ansible_user) -m file -a "path=$(abspath $(dir $(MAKEFILE_LIST))/../../..) mode=0777 \
          state=directory" --become
	PACKET_NET_API_KEY=$(packet_api_key) ansible $(all_instances) \
          -i ../ansible/$(inventory_script) --ssh-common-args="-o StrictHostKeyChecking=no \
          -i  $(cluster_full_pem)"  -u $(ansible_user) -m synchronize -a "src=$(abspath \
          $(dir $(MAKEFILE_LIST))/../..) dest=$(abspath $(dir $(MAKEFILE_LIST))/../../..) \
          recursive=yes rsync_opts=\"--exclude=.git -e 'ssh  -o StrictHostKeyChecking=no \
          -i $(cluster_full_pem)'\""
	@echo "\033[36m==> Successfully ran ansible to rsync wallaroo repo to cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'!\033[0m"


configure: check-cluster-name ## Configure nodes using ansible
	@echo "\033[36m==> Running ansible playbook for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'...\033[0m"
	PACKET_NET_API_KEY=$(packet_api_key) ansible-playbook $(ansible_parallelism_arg) \
          --timeout=30 -i \
          ../ansible/$(inventory_script) --ssh-common-args="-o StrictHostKeyChecking=no -i \
          $(cluster_full_pem)" --extra-vars "cluster_name=$(cluster_name) \
          cluster_project_name=$(cluster_project_name) \
          $(provider)_region=$(region) isolcpus=$(ansible_isolcpus) \
	  install_devtools=$(ansible_install_devtools) ssh_key_file=$(cluster_full_pem) \
          $(ansible_raid_level_arg) $(ansible_raid_fs_arg) \
          $(ansible_sys_cpus_arg)" -u $(ansible_user) \
          ../ansible/playbooks/$(provider).yml
	@echo "\033[36m==> Successfully ran ansible playbook for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)'!\033[0m"

plan: check-cluster-name $(if $(filter $(provider),aws),acquire-vpc-lock create-vpc release-vpc-lock) acquire-cluster-lock init-terraform setup_$(provider)_ci_arg setup_$(provider)_az_arg terraform-plan post_message release-cluster-lock ## Run terraform plan step

apply: check-cluster-name $(if $(filter $(provider),aws),acquire-vpc-lock create-vpc release-vpc-lock) acquire-cluster-lock init-terraform setup_$(provider)_ci_arg setup_$(provider)_az_arg terraform-apply post_message release-cluster-lock ## Run terraform apply step (set use_automagic_instances=false to be able to change more than # instances)

setup_aws_ci_arg: exists=$(shell egrep 'resources' \
                ./$(provider)-cluster/.terraform/terraform.tfstate | sort -u | sed \
                -e 's/.*: \(.*\)/\1/')
setup_aws_ci_arg: old_num_followers=$(shell egrep -A 15 'followers' \
                ./$(provider)-cluster/.terraform/terraform.tfstate | grep desired_capacity \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_aws_ci_arg: old_num_leaders=$(shell egrep -A 15 'leaders' \
                ./$(provider)-cluster/.terraform/terraform.tfstate | grep desired_capacity \
                | sed -e 's/.*: "\(.*\)",/\1/')
setup_aws_ci_arg: leader_num=$(if $(num_leaders),$(num_leaders),$(old_num_leaders))
setup_aws_ci_arg: follower_num=$(if $(num_followers),$(num_followers),$(old_num_followers))
setup_aws_ci_arg: num_instances_args=num_leaders_arg=$(if $(leader_num),-var \
                'leader_default_nodes="$(leader_num)"',)@num_followers_arg=$(if $(follower_num),-var \
                'follower_default_nodes="$(follower_num)"',)
setup_aws_ci_arg: old_price=$(shell egrep 'spot_price' \
                $(current_dir)/$(provider)-cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_aws_ci_arg: old_az=$(shell egrep 'availability_zones' \
                $(current_dir)/$(provider)-cluster/.terraform/terraform.tfstate | sort -u \
                | grep -v '#' | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_aws_ci_arg: old_type=$(shell egrep 'instance_type' \
                $(current_dir)/$(provider)-cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_aws_ci_arg: old_pg=$(shell egrep 'placement_group.:' \
                $(current_dir)/$(provider)-cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_aws_ci_arg: old_pg_args=$(if $(old_pg),ci_pg=is using placement groups\
       #pg_arg=-var placement_group=$(old_pg),ci_pg=is not using placement groups)
setup_aws_ci_arg: tmp_ci_args=$(if $(filter $(use_automagic_instances),true),$(if \
       $(old_type),ci_old_values=true#ci_inst_type=$(old_type)#$(old_pg_args)\
       #ci_inst_price=$(old_price)#ci_az=$(old_az)#availability_zone=$(old_az)\
       #ci_current_price=???#ci_args=-var leader_instance_type=$(old_type) -var \
       follower_instance_type=$(old_type) -var 'leader_spot_price="$(old_price)"' \
       -var 'follower_spot_price="$(old_price)"',$(shell\
       $(current_dir)/automagic_instance.py --region $(region) --cpus \
       $(cpus_required) --mem $(mem_required) $(no_burst_arg) \
       --spot-bid-factor $(spot_bid_factor) --availability_zone \
       "$(availability_zone)" $(no_spot_arg) --instance_type "$(force_instance)")))
setup_aws_ci_arg: # set up automagic instances arg
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

setup_packet_ci_arg: exists=$(shell egrep 'resources' \
                ./$(provider)-cluster/.terraform/terraform.tfstate | sort -u | sed \
                -e 's/.*: \(.*\)/\1/')
setup_packet_ci_arg: old_num_followers=$(shell egrep -o 'wallaroo-follower-\d+' \
                ./$(provider)-cluster/.terraform/terraform.tfstate | wc -l \
                | awk '{print ($$1>0)?$$1:$$9}')
setup_packet_ci_arg: old_num_leaders=$(shell egrep -o 'wallaroo-leader-\d+' \
                ./$(provider)-cluster/.terraform/terraform.tfstate | wc -l \
                | awk '{print ($$1>0)?$$1:$$9}')
setup_packet_ci_arg: leader_num=$(if $(num_leaders),$(num_leaders),$(old_num_leaders))
setup_packet_ci_arg: follower_num=$(if $(num_followers),$(num_followers),$(old_num_followers))
setup_packet_ci_arg: num_instances_args=num_leaders_arg=$(if $(leader_num),-var \
                'leader_default_nodes="$(leader_num)"',)@num_followers_arg=$(if $(follower_num),-var \
                'follower_default_nodes="$(follower_num)"',)
setup_packet_ci_arg: old_type=$(shell egrep 'plan' \
                $(current_dir)/$(provider)-cluster/.terraform/terraform.tfstate | sort -u \
                | sed -e 's/.*: "\(.*\)",/\1/' | head -n 1)
setup_packet_ci_arg: tmp_ci_args=$(if \
       $(old_type),ci_old_values=true#ci_inst_type=$(old_type)\
       #ci_args=-var leader_instance_type=$(old_type) -var \
       follower_instance_type=$(old_type),ci_args=-var leader_instance_type=$(force_instance) -var \
       follower_instance_type=$(force_instance))
setup_packet_ci_arg: # set up instances arg
	@echo $(if $(filter $(exists),{), $(if \
          $(in_cluster),$(error Can't create an existing cluster! Use apply \
          instead to modify it.)))
	$(eval $(subst @,$(newline),$(num_instances_args)))
	$(eval $(subst #,$(newline),$(tmp_ci_args)))


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
'$(region)' at provider '$(provider)'...\033[0m"
	cd $(provider)-vpc && terraform apply $(terraform_args) -var $(provider)_region=$(region) \
          $(shell aws ec2 --region $(region) describe-availability-zones \
          --query 'AvailabilityZones[*].ZoneName' --output text | awk \
          'function f(v) {return v == 0 ? 2: (v < 0 ? -v : v)} {print \
          "-var aws_availability_zone_1=" $$(f(NF - 1)) \
          " -var aws_availability_zone_2=" $$(f(NF - 3)) \
          " -var aws_availability_zone_3=" $$(f(NF - 4)) \
          " -var aws_availability_zone_4=" $$(f(NF - 5))}')
	@echo "\033[36m==> Successfully confirmed VPC is created in region \
'$(region)' at provider '$(provider)'!\033[0m"

destroy-vpc: check-cluster-name init-vpc-terraform # destroy VPC in region
	@echo "\033[36m==> Destroying VPC in region '$(region)' at provider '$(provider)'...\033[0m"
	cd $(provider)-vpc && terraform destroy -force $(terraform_args) -var \
          $(provider)_region=$(region)
	@echo "\033[36m==> Successfully confirmed VPC is created in region \
'$(region)' at provider '$(provider)'!\033[0m"

acquire-cluster-lock: check-cluster-name ## Acquire cluster lock in order to safely run terraform commands on shared remote state in S3
	@echo "\033[36m==> Acquiring cluster lock...\033[0m"
	aws configure set preview.sdb true
	aws sdb create-domain --region $(terraform_locking_aws_region) --domain-name terraform_locking
        # create lock item if needed
	-aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=free,Replace=true \
          --expected Name=$(cluster_name)-lock,Exists=false
        # get a free lock
	-aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=$(cluster_name)-lock,Value=free
        # next command is for when a previous make target failed without releasing a lock
	aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> Cluster lock successfully acquired!\033[0m"

acquire-vpc-lock: check-cluster-name ## Acquire vpc lock in order to safely run terraform commands on shared remote state in S3
	@echo "\033[36m==> Acquiring vpc lock...\033[0m"
	aws configure set preview.sdb true
	aws sdb create-domain --region $(terraform_locking_aws_region) --domain-name terraform_locking
        # create lock item if needed
	-aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=vpc-lock,Value=free,Replace=true \
          --expected Name=vpc-lock,Exists=false
        # get a free lock
	-aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=vpc-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=vpc-lock,Value=free
        # next command is for when a previous make target failed without releasing a lock
	aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=vpc-lock,Value=`id -u -n`-`hostname`,Replace=true \
          --expected Name=vpc-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> VPC lock successfully acquired!\033[0m"

check-cluster-name: # check for valid cluster name
	$(if $(cluster_name),,$(error 'cluster_name' cannot be empty!))
	$(if $(filter $(cluster_name),$(shell echo '$(cluster_name)' | sed 's/[^a-zA-Z0-9\-\.]//g')),,$(error 'cluster_name' can only have [a-zA-Z0-9-.] in it!))

init-vpc-terraform: check-cluster-name ## Initialize/reset local terraform state based on what is in S3 for vpc
	@echo "\033[36m==> Initializing terraform state for VPC in region \
'$(region)' at provider '$(provider)' with remote S3 config...\033[0m"
	cd $(provider)-vpc && rm -f .terraform/terraform.tfstate
	cd $(provider)-vpc && rm -f .terraform/terraform.tfstate.backup
	cd $(provider)-vpc && terraform remote config -backend=s3 \
          -backend-config="bucket=$(terraform_state_aws_bucket)" \
          -backend-config="region=$(terraform_state_aws_region)" \
          -backend-config="key=terraform-state/vpc/$(region)-terraform.tfstate"
	@echo "\033[36m==> Terraform state successfully initialized for VPC in \
region '$(region)' at provider '$(provider)'!\033[0m"

setup_aws_az_arg: tmp_az_arg=$(if $(availability_zone),-var aws_subnet_id=$(shell \
                aws ec2 --region $(region) describe-subnets --filters \
                Name=availabilityZone,Values=$(availability_zone) \
                Name=tag:Project,Values=wallaroo --query \
                'Subnets[*].{SubnetId:SubnetId}' --output text | head -n 1),)
setup_aws_az_arg: # set up availability zone arg
	$(if $(availability_zone),$(if $(subst -var \
          aws_subnet_id=,,$(tmp_az_arg)),,$(error Unable to look up\
          subnet for AZ $(availability_zone) in region $(region)!)),)
	$(eval az_arg=$(tmp_az_arg))

setup_packet_az_arg:

init-terraform: ## Initialize/reset local terraform state based on what is in S3 for cluster
	@echo "\033[36m==> Initializing terraform state for cluster \
'$(cluster_name)' in region '$(region)' at provider '$(provider)' with remote S3 config...\033[0m"
	cd $(provider)-cluster && rm -f .terraform/terraform.tfstate
	cd $(provider)-cluster && rm -f .terraform/terraform.tfstate.backup
	cd $(provider)-cluster && terraform remote config -backend=s3 \
          -backend-config="bucket=$(terraform_state_aws_bucket)" \
          -backend-config="region=$(terraform_state_aws_region)" \
          -backend-config="key=terraform-state/cluster/$(provider)-$(region)-$(cluster_name)-terraform.tfstate"
	@echo "\033[36m==> Terraform state successfully initialized for cluster\
 '$(cluster_name)' in region '$(region)' at provider '$(provider)'!\033[0m"

release-cluster-lock: check-cluster-name ## Release cluster lock after safely running terraform commands on shared remote state in S3
	@echo "\033[36m==> Releasing cluster lock...\033[0m"
	aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=free,Replace=true \
          --expected Name=$(cluster_name)-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> Cluster lock successfully released!\033[0m"

force-release-cluster-lock: check-cluster-name ## Force release cluster lock (NOTE: ONLY USE IN EMERGENCY ELSE IT COULD CORRUPT TERRAFORM CACHE!!!!)
	@echo "\033[36m==> Forcing release of cluster lock...\033[0m"
	aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=$(cluster_name)-lock,Value=free,Replace=true
	@echo "\033[36m==> Cluster lock successfully released!\033[0m"

force-delete-cluster-state: check-cluster-name ## Force delete cluster state (NOTE: ONLY USE IN EMERGENCY AS IT DELETES TERRAFORM CACHE!!!!)
	@echo "\033[36m==> Forcing delete of terraform cluster state...\033[0m"
	aws s3 rm s3://$(terraform_state_aws_bucket)/terraform-state/cluster/$(provider)-$(region)-$(cluster_name)-terraform.tfstate
	@echo "\033[36m==> Cluster terraform state successfully deleted!\033[0m"
	@echo "\033[36m==> NOTE: PLEASE MAKE SURE TO MANUALLY DELETE ANY LINGERING RESOURCES!!!\033[0m"

release-vpc-lock: check-cluster-name ## Release vpc lock after safely running terraform commands on shared remote state in S3
	@echo "\033[36m==> Releasing vpc lock...\033[0m"
	aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
          Name=vpc-lock,Value=free,Replace=true \
          --expected Name=vpc-lock,Value=`id -u -n`-`hostname`
	@echo "\033[36m==> VPC lock successfully released!\033[0m"

force-release-vpc-lock: check-cluster-name ## Force release vpc lock (NOTE: ONLY USE IN EMERGENCY ELSE IT COULD CORRUPT TERRAFORM CACHE!!!!)
	@echo "\033[36m==> Forcing release of vpc lock...\033[0m"
	aws sdb put-attributes --region $(terraform_locking_aws_region) --domain-name \
          terraform_locking --item-name $(provider)-$(region)_lock --attributes \
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
	@grep -h -o '"[^"]*"' $(current_dir)/*cluster/variables.tf | tr '\n' ' ' \
          | grep -o '"[^"]*" "[^"]*" "[^"]*"' | grep -v cluster_name | grep -v \
          subnet_id | grep -v placement_group | grep -v project_tag | grep -v \
          aws_region | grep -v packet_region | grep -v ami | awk -F\" '{printf \
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

# rule to print info about make variables, works only with make 3.81 and above
# to use invoke make with a target of print-VARNAME, e.g.,
# make print-CCFLAGS
print-%:
	@echo '$*=$($*)'
	@echo '  origin = $(origin $*)'
	@echo '  flavor = $(flavor $*)'
	@echo '   value = $(value  $*)'

