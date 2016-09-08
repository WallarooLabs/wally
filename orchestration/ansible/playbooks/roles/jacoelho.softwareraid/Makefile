default: test

test: test_default test_force_create

test_default:
	vagrant destroy -f
	PLAYBOOK_FILE='test_default.yml' vagrant up

test_force_create:
	vagrant destroy -f
	PLAYBOOK_FILE='test_force_create.yml' vagrant up
