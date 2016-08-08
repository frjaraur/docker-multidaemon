boxes = [
    {
        :node_mgmt_name => "node1",
        :node_mgmt_ip => "10.10.10.11",
        :node_service_name => "service1",
        :node_service_ip => "10.10.11.11",
        :swarm_role => "manager",
        :node_mem => "1524",
        :node_cpu => "1",
        :node_role => "node",
        :node_hostonlyip=> "192.168.56.11"
    },
    {
        :node_mgmt_name => "node2",
        :node_mgmt_ip => "10.10.10.12",
        :node_service_name => "service2",
        :node_service_ip => "10.10.11.12",
        :swarm_role => "manager",
        :node_mem => "1524",
        :node_cpu => "1",
        :node_role => "node",
        :node_hostonlyip=> "192.168.56.12"
    },
    {
        :node_mgmt_name => "node3",
        :node_mgmt_ip => "10.10.10.13",
        :node_service_name => "service3",
        :node_service_ip => "10.10.11.13",
        :swarm_role => "manager",
        :node_mem => "1524",
        :node_cpu => "1",
        :node_role => "node",
        :node_hostonlyip=> "192.168.56.13"
    },
    {
        :node_mgmt_name => "node4",
        :node_mgmt_ip => "10.10.10.14",
        :node_service_name => "service4",
        :node_service_ip => "10.10.11.14",
        :swarm_role => "worker",
        :node_mem => "1524",
        :node_cpu => "1",
        :node_role => "node",
        :node_hostonlyip=> "192.168.56.14"
    },

]

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.synced_folder "tmp_deploying_stage/", "/tmp_deploying_stage",create:true
  config.vm.synced_folder "src/", "/src",create:true


  boxes.each do |opts|
    config.vm.define opts[:node_mgmt_name] do |config|
      config.vm.hostname = opts[:node_mgmt_name]
      config.vm.provider "virtualbox" do |v|
        v.name = opts[:node_mgmt_name]
        v.customize ["modifyvm", :id, "--memory", opts[:node_mem]]
        v.customize ["modifyvm", :id, "--cpus", opts[:node_cpu]]
      end

      # config.vm.network "public_network",
      # bridge: "wlan0" ,
      # use_dhcp_assigned_default_route: true

      config.vm.network "private_network",
      ip: opts[:node_mgmt_ip],
      virtualbox__intnet: "DOCKER_MGMT_SWARM"

      config.vm.network "private_network",
      ip: opts[:node_service_ip],
      virtualbox__intnet: "DOCKER_SERVICE_SWARM"

      #  config.vm.network "private_network",
      #  ip: opts[:node_hostonlyip], :netmask => "255.255.255.0",
      #  :name => 'vboxnet0',
      #  :adapter => 2


    #  if opts[:swarm_role] == "keyvalue"
    #	  config.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true
    #  end

      # config.vm.provision "shell", inline: <<-SHELL
      #   sudo apt-get update -qq
      # SHELL


      # Delete default router for host-only-adapter
    #  config.vm.provision "shell",
    #    run: "always",
    #    inline: "route del default gw 192.168.56.1"


      ## INSTALL DOCKER ENGINE --> on script because we can reprovision
      #config.vm.provision "shell", inline: <<-SHELL
      #
      #SHELL

      ## ADD HOSTS
      config.vm.provision "shell", inline: <<-SHELL
        echo "127.0.0.1 localhost" >/etc/hosts
        echo "10.10.10.11 node1 node1.dockerlab.local" >>/etc/hosts
        echo "10.10.10.12 node2 node2.dockerlab.local" >>/etc/hosts
        echo "10.10.10.13 node3 node3.dockerlab.local" >>/etc/hosts
        echo "10.10.10.14 node4 node4.dockerlab.local" >>/etc/hosts

        echo "10.10.11.11 service1 service1.dockerlab.local" >>/etc/hosts
        echo "10.10.11.12 service2 service2.dockerlab.local" >>/etc/hosts
        echo "10.10.11.13 service3 service3.dockerlab.local" >>/etc/hosts
        echo "10.10.11.14 service4 service4.dockerlab.local" >>/etc/hosts

      SHELL

      config.vm.provision "file", source: "multidaemon.sh", destination: "/home/vagrant/multidaemon.sh"
      config.vm.provision :shell, :path => 'multidaemon.sh' , :args => [ opts[:node_mgmt_ip],opts[:node_service_ip], opts[:swarm_role] ]

    end
  end

end
