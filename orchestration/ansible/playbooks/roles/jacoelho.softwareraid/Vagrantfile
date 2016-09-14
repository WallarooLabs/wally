# -*- mode: ruby -*-
# vi: set ft=ruby :

hosts = [ { name: 'test', cpu_cap: "50", cpus: "1", ram: "512", disk1: './test_disk1.vdi', disk2: 'test_disk2.vdi' }]

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  #config.vm.provider :virtualbox do |vb|
  # vb.customize ["storagectl", :id, "--add", "sata", "--name", "SATA" , "--portcount", 2, "--hostiocache", "on"]
  #end

  hosts.each do |host|

    config.vm.define host[:name] do |node|
      node.vm.hostname = host[:name]
      node.vm.box = "ubuntu/trusty64"
      node.vm.provider :virtualbox do |vb|
        vb.name = host[:name]
        vb.customize ["modifyvm", :id, "--cpuexecutioncap", host[:cpu_cap]]
        vb.customize ["modifyvm", :id, "--memory", host[:ram]]
        vb.customize ["modifyvm", :id, "--cpus", host[:cpus]]
        vb.customize ['createhd', '--filename', host[:disk1], '--size', 2 * 1024]
        vb.customize ['createhd', '--filename', host[:disk2], '--size', 2 * 1024]
        vb.customize ['storageattach', :id, '--storagectl', "SATAController", '--port', 1, '--device', 0, '--type', 'hdd', '--medium', host[:disk1] ]
        vb.customize ['storageattach', :id, '--storagectl', "SATAController", '--port', 2, '--device', 0, '--type', 'hdd', '--medium', host[:disk2] ]
      end
    end

    # information on available options.
    config.vm.provision "ansible" do |ansible|
      ansible.playbook = ENV['PLAYBOOK_FILE']
      ansible.verbose = 'vv'
      ansible.sudo = true
    end

  end

end
