Aplanci VPN
===========

This is an Ansible playbook for setting up a Wireguard VPN with a hub-and-spoke architecture:
```
        Private subnets             .____Wireguard____.
               |                    |   connections   |
+-----------+  |  +--------------+  |                 | +-------------+               
| client #1 |-----| VPN entry #1 |=====\          /=====| VPN exit #1 |----\
+-----------+  |  +--------------+  | +-------------+ | +-------------+   +----------+
               |                    | | VPN gateway | |                   | internet |
+-----------+  |  +--------------+  | +-------------+ | +-------------+   +----------+
| client #2 |-----| VPN entry #2 |=====/          \=====| VPN exit #2 |----/
+-----------+     +--------------+                      +-------------+               
```

The traffic from the clients is routed through the VPN to their respective exit nodes which double as a NAT gateway.
The rulebook provides a way of defining port-forwarding rules from the edge to each client.

Currently supported host OSes are Debian 10 and 11.

Configuration
-------------

# Ansible vault key

Drop the vault pass in `~/.ansible-vault-key` (keep this file out of the repository)
```
echo "securepassword" > ~/.ansible-vault-key
```

# Group variables

## All groups

1. Edit `group_vars/all_groups/vars` and change `ssh_port` to a port of your choosing.
2. Create a password hash with `mkpasswd` (available in the `whois` package on debian)
```
mkpasswd --method=sha-512 
```
3. Create a vault with a user and password that will be used for all hosts 
```
ansible-vault create --vault-password-file ~/.ansible-vault-key group_vars/all_groups/vault
```
Set a user name and password:
```
vault_setup_user: bob
vault_setup_password: <<hashed password from the previous step>>
```

## Staging

Staging is intended as example configuration and for development of the playbook. It can used to test out a configuration with Vagrant.
```
vagrant up
vagrant ssh client1
client1$ traceroute 1.1.1.1
```

## Prod

The configuration has four sections:

### PVS
This section defines the unencrypted private subnets which the clients use
to connect to the VPN entry nodes
```
pvs:
  pvs1:                  # Subnet name
    net: "10.20.30.0/24" # Private subnet shared by the client and VPN entry node
    gw: "10.20.30.14"    # VPN entry node address on the private subnet
    entry: vpnentry1     # VPN entry node name as in inventory
    table: 200           # Routing table id used by the VPN gateway
```

### Hosts

This section defines the interfaces and subnets of each host:
```
hosts:
  vpnentry1:                      # VPN entry node name as in the inventory
    pvs: pvs1                     # PVS name as in the PVS section
    interfaces:
      default:                    # Interface used to connect to the VPN gateway
        interface: eth0           # Interface name
        ip: "192.168.1.2/24"      # Static IP
        gw: "192.168.1.1"         # Gateway
      pvs:                        # Private subnet, client-facing interface
        interface: eth1           # Interface name
        ip: "10.10.10.1/24"       # Static IP facing the client
  client1:
    pvs: pvs1                     # PVS name as in the PVS section
    interfaces:
      default:                    # SSH interface
        interface: eth0
        ip: "192.168.121.171/24"
        gw: "192.168.121.1"
      pvs:                        # Private subnet, VPN entry-facing interface
        interface: eth1
        ip: "10.10.10.2/24"       # Client IP, can be used for port forwarding
  vpnexit1:                       # VPN exit node name as in the inventory
    interfaces:
      default:                    # Public facing interface used to connect to the VPN gateway and internet
        interface: eth0
  vpnvm:                          # VPN gateway
    interfaces:
      default:                    # Public facing interface used to connect to the VPN peers and internet
        interface: eth0
```

### Circuits
This section defines how traffic should be routed through the VPN
```
circuits:
  pvs1:                 # PVS name, as in the PVS section
    entry: "vpnentry1"  # Entry node name as in the inventory
    exit: "vpnexit1"    # Exit node name as in the inventory
    forward:            # Port forwarding, where "dst" is the private client IP
      - { proto: "tcp", dst: "10.10.10.2", port: "1234" }
      - { proto: "udp", dst: "10.10.10.2", port: "1234" }

```

### Peers
This section defines how the Wireguard connections are setup between the VPN entry/exit nodes (peers) and the gateway
```
vpn_peers:
  vpnentry1:              # Entry node name as in the inventory
    port: 51820           # Port to listen on, on the VPN gateway
    client: 10.69.110.122 # Entry node IP on the link
    gw: 10.69.110.221     # Gateway's IP on the link
    interface: wg0        # Interface name on the gateway
  vpnexit1:               # Exit node name as in the inventory
    port: 51821           # Port to listen on, on the VPN gateway
    client: 10.69.110.123 # Exit node IP on the link
    gw: 10.69.110.132     # Gateway's IP on the link
    interface: wg1        # Interface name on the gateway
    site: pvs1            # PVS name as in the PVS section
```

# Inventory

Add all hosts to the inventory in `inventories/staging/home`
- `ansible_user` should match `vault_setup_user`
- `ansible_port` should match `ssh_port`
```
crescentfresh ansible_host=1.2.3.4 ansible_user='bob' ansible_port=1419 ansible_python_interpeter=/usr/bin/python3
```

Copy your pubkey in the templates directory
```
cp ~/.ssh/id_rsa.pub roles/bootstrap/templates/home/setup_user/.ssh/authorized_keys
```

If you need multiple keys, append them to the `authorized_keys` file you just created.

Encrypt the above secrets using the vault
```
ansible-vault encrypt group_vars/all_groups/vault roles/bootstrap/templates/home/setup_user/.ssh/authorized_keys
```

# Wireguard keys

Generate Wireguard keys for each node and the gateway:
```
./genkeys.sh vpnentry1 vpnexit1 vpnvm
```
Names should match the host names from the inventory.

Setup
-----

The setup requires two steps for each host.

The first step is to run a "bootstrap" playbook once for each VPN host (not clients).
This will lock down the access to the host:
- Disables password authentication
- Installs a public SSH key
- Moves SSH to a different port
- Limits the log journal size

The second step is to run the "vpn" rulebook that will set up the VPN proper.

The bootstrap playbook should be executed only once on each new host in the VPN.
After that, the vpn playbook can be ran multiple times to update the hosts.

# boostrap.yml

This will lock down the host's SSH with public key authorization before setting up the VPN proper.

Run the playbook, assuming the root user on the remote host is password authenticated:
```
ssh 1.2.3.4 # Connect to the host to add the SSH key to the known host, you can terminate with Ctrl+C after the key is added
ansible-playbook --vault-password-file ~/.ansible-vault-key -i inventories/production/home -l vpnentry1 -k bootstrap.yml -e ansible_port=22 -e ansible_user=root
```
You will have to type in the root password for each host once.

# vpn.yml

Run the playbook to setup the VPN
```
ansible-playbook --vault-password-file ~/.ansible-vault-key -i inventories/production/home -l all vpn.yml
```

Done! The clients should be able to reach the internet through the VPN.

Make sure to configure the clients to use their respective entry nodes PVS IP's as their default gateways.
