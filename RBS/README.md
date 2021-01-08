# Overview:

Lists out all VMware VMs, Nutanix VMs, Windows and Linux Hosts and their RBS status

# Requirements: 

jq - a lightweight and flexible command-line JSON processor.

openssl - create the Base64 encoding of username:password used for authentication

curl - call the Rubrik CDM RESTful API

# Usage: 

`list_rbs_status.sh -c "Rubrik-node-IP" -u "Username" -p "Password" <optional>`
