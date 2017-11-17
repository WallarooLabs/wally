hosts_file ?= hosts## Hosts inventory file for ansible
private_key ?= ## Private key to use
node_hostname ?= ## Hostname to flash
hypriot_image ?= https://downloads.hypriot.com/hypriot-rpi-20160306-192317.img.zip## hypriot image url
hypriot_flash_tool ?= https://github.com/hypriot/flash.git## hypriot flash tool
tmp_storage ?= /tmp/hypriot## Location to store flash tool and hypriot image

.PHONY: configure-rpi flash-rpi-node download-flash-tool download-image \
        test-ansible

default: configure-rpi

download-flash-tool: ## download hypriot flash tool
	@echo "\033[36m==> Downloading flashing tool...\033[0m"
	$(if $(wildcard $(tmp_storage)/hypriot-flash),git -C \
          $(tmp_storage)/hypriot-flash pull || (rm -r \
          $(tmp_storage)/hypriot-flash && git clone $(hypriot_flash_tool) \
          $(tmp_storage)/hypriot-flash),\
          git clone $(hypriot_flash_tool) $(tmp_storage)/hypriot-flash)
	@echo "\033[36m==> Successfully downloaded flash tool!\033[0m"

download-image: ## download hypriot image
	@echo "\033[36m==> Downloading hypriot image...\033[0m"
	cd $(tmp_storage) && curl -C - -o $(notdir $(hypriot_image)) \
          $(hypriot_image)
	@echo "\033[36m==> Successfully downloaded hypriot image!\033[0m"

flash-rpi-node: download-flash-tool download-image ## Flash RPi nodes
	$(if $(node_hostname),,$(error node_hostname \
          to flash ($(node_hostname)) is missing!))
	@echo "\033[36m==> Flashing node...\033[0m"
	$(tmp_storage)/hypriot-flash/$(shell uname -s)/flash --hostname \
          $(node_hostname) $(tmp_storage)/$(notdir $(hypriot_image))
	@echo "\033[36m==> Successfully flashed node!\033[0m"

test-ansible: ## test ansible connection to nodes
	$(if $(wildcard $(hosts_file)),,$(error Ansible Inventory \
          file ($(hosts_file)) is missing!))
	$(if $(wildcard $(private_key)),,$(error SSH private key \
          file ($(private_key)) is missing!))
	@echo "\033[36m==> Running ansible test for RPi cluster...\033[0m"
	ansible -i hosts \
          --ssh-common-args="-o StrictHostKeyChecking=no -i $(private_key)" \
          -u root -m ping all
	@echo "\033[36m==> Successfully ran ansible test for RPi \
cluster!\033[0m"


configure-rpi: ## Configure nodes using ansible
	$(if $(wildcard $(hosts_file)),,$(error Ansible Inventory \
          file ($(hosts_file)) is missing!))
	$(if $(wildcard $(private_key)),,$(error SSH private key \
          file ($(private_key)) is missing!))
	@echo "\033[36m==> Running ansible playbook for RPi cluster...\033[0m"
	ansible-playbook -i\
          hosts --ssh-common-args="-o StrictHostKeyChecking=no -i \
          $(private_key)" -u root ../ansible/playbooks/hypriot.yml
	@echo "\033[36m==> Successfully ran ansible playbook for RPi \
cluster!\033[0m"

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

