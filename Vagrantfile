# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  config.vm.synced_folder ".", "/vagrant",
    type: "nfs",
    nfs_version: 4,
    nfs_udp: false

  config.vm.provider "libvirt" do |lv|
    lv.cpu_mode = 'custom'
    lv.cpu_model = 'kvm64'
    lv.video_type = 'virtio'
    lv.memory = 1024
    lv.storage_pool_name = 'pool'
    lv.uuid
    lv.disk_bus = 'scsi'
  end

  ["client1", "vpnentry1", "client2", "vpnentry2"].each do |machine_id|
    config.vm.box = "wg/debian"
    config.vm.define machine_id do |machine|
      # Only execute once the Ansible provisioner,
      # when all the machines are up and ready.
      machine.vm.hostname = machine_id

      if machine_id == "client1"
	machine.vm.network "private_network", :libvirt__dhcp_enabled => false, :libvirt__forward_mode => "none",
	  ip: "10.30.37.196",
          auto_config: false
      end

      if machine_id == "client2"
	machine.vm.network "private_network", :libvirt__dhcp_enabled => false, :libvirt__forward_mode => "none",
	  ip: "10.31.37.196",
          auto_config: false
      end

      if machine_id == "vpnentry1"
	machine.vm.network "private_network", :libvirt__dhcp_enabled => false, :libvirt__forward_mode => "none",
          ip: "10.30.37.243",
          auto_config: false
      end

      if machine_id == "vpnentry2"
	machine.vm.network "private_network", :libvirt__dhcp_enabled => false, :libvirt__forward_mode => "none",
          ip: "10.31.37.243",
          auto_config: false
      end
    end
  end

  ["vpnvm", "vpnexit1", "vpnexit2"].each do |machine_id|
    config.vm.box = "wg/debian"
    config.vm.define machine_id do |machine|
      # Only execute once the Ansible provisioner,
      # when all the machines are up and ready.
      machine.vm.hostname = machine_id

      if machine_id == "vpnexit2"
        machine.vm.provision :ansible do |ansible|
          # Disable default limit to connect to all the machines
          ansible.limit = "all"
          ansible.playbook = "vpn.yml"
          ansible.vault_password_file = '~/.ansible-vault-key'
          ansible.extra_vars = { ansible_python_interpreter:"/usr/bin/python3" }
          ansible.verbose = true
          ansible.groups = {
            "client" => ["client1", "client2"],
            "vpn_staging" => ["vpnvm","vpnexit1","vpnentry1","vpnexit2","vpnentry2"],
            "pvs_staging" => ["client1","vpnentry1","client2","vpnentry2"],
            "vpn_gateway" => ["vpnvm"],
            "vpn_client" => ["vpnexit1", "vpnentry1", "vpnexit2", "vpnentry2"],
            "vpn_exit" => ["vpnexit1","vpnexit2"],
            "vpn_entry" => ["vpnentry1", "vpnentry2"],
            "pvs1" => ["vpnentry1", "client1"],
            "pvs2" => ["vpnentry2", "client2"],
            "pvs:children" => ["pvs1", "pvs2"],
            "vpn:children" => ["vpn_gateway", "vpn_client"],
            "all_groups:children" => ["vpn", "pvs_staging", "pvs", "client"],
            "staging:children" => ["vpn", "pvs_staging", "pvs", "client"]
          }
        end
      end
    end
  end
end
