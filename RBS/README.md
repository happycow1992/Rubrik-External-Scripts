# Overview:

Lists out all VMware VMs, Nutanix VMs, Windows and Linux Hosts and their RBS status (Registered/Unregistered)
( For VMs ) If RBS installed and Registered - Connected 

( For VMs ) If RBS installed and Not Registered - Unregistered

( For VMs ) If RBS not installed and Not Registered - Unregistered

( For Hosts ) If Host Connected - RBS is valid for connectivity - Connected

( For Hosts ) If RBS installed and Host is Disconnected - Host Connection unstable - Disconnected

# Requirements: 

jq - a lightweight and flexible command-line JSON processor.

openssl - create the Base64 encoding of username:password used for authentication

curl - call the Rubrik CDM RESTful API

# Usage: 

`list_rbs_status.sh -c "Rubrik-node-IP" -u "Username" -p "Password" <optional>`
