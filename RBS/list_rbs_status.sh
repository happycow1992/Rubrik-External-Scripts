#!/bin/bash

#Prints usage
function usage
{
        printf "Usage\t[-c <IP_ADDRESS>]\n\t[-u <USERNAME>]\n\t[optional -p <PASSWORD> ]\n\t[-h help]\n\n" 1>&2; exit 1;
}

# Switches to be used for script
while getopts c:u:p:h: arg
do
        case "${arg}"
        in
                c) CLUSTER=${OPTARG};;
                u) USERNAME=${OPTARG};;
                p) PASSWORD=${PASSWORD};;
                h) usage;;
                *) printf "\nUse -h for help\n\n";;
        esac
done

shift $((OPTIND-1))
if [ -z "${CLUSTER}" ] || [ -z "${USERNAME}" ]; then
    usage
fi

# Check if jq is installed
if ! JQ_LOC="$(type -p jq)" || [ -z "$JQ_LOC" ]; then
  printf '%s\n' "The jq utility is not installed."
  printf '%s\n' "Install contructions can be found at https://stedolan.github.io/jq/download/"
  exit 1
fi

# Check if password was passed as part of script or not
if [ -z $PASSWORD ]
then
	printf "Enter Password: "
        read -s PASSWORD
fi

# Hash entered username password via openssl
hash_password=$(echo -n "$USERNAME:$PASSWORD" | openssl enc -base64)
echo

# Get Cluster UUID
clusterUID=$(curl -s -H 'Content-Type: application/json' -H 'Authorization: Basic '"$hash_password"'' -X GET -k -l --write-out "HTTPSTATUS:%{http_code}" --connect-timeout 5  "https://$CLUSTER/api/v1/cluster/me")

HTTP_STATUS=$(echo $clusterUID | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# extract the status
HTTP_STATUS=$(echo $clusterUID | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# Provide an Error Message if there is no connectivity to the Cluster
if [ "$HTTP_STATUS" == "000" ]; then
  printf '%s\n' "ERROR: Unable to connect to $CLUSTER."
  exit 1
fi

# Provide an Error Message for any response other than 200 (success)
if [ "$HTTP_STATUS" != "200" ]; then
  ERROR_RESPONSE="${clusterUID//'HTTPSTATUS:'$HTTP_STATUS}"
  ERROR_MESSAGE=$( echo "$ERROR_RESPONSE" | jq -r '.message' )
  printf '%s\n' "ERROR: $ERROR_MESSAGE"
  exit 1
fi

clusterUUID=$(curl -s -X GET "https://$CLUSTER/api/v1/cluster/me" -H "accept: application/json" -H "authorization: Basic "$hash_password"" -k | python -m json.tool   | jq -r '(.id)')

clusterName=$(curl -s -X GET "https://$CLUSTER/api/v1/cluster/me" -H "accept: application/json" -H "authorization: Basic "$hash_password"" -k | python -m json.tool  | jq -r '(.name)')

# Get All non Archived VMs:
echo "VMware-VMs" >> RBS_Objects_$clusterName.csv
curl -s -X GET "https://$CLUSTER/api/v1/vmware/vm?is_relic=false" -H "accept: application/json" -H "authorization: Basic "$hash_password"" -k | python -m json.tool | jq -r '.data[] | [.name] + [.guestOsName // "null"] + [(.agentStatus.agentStatus)] |@sh' | column -t -s "'" >> RBS_Objects_$clusterName.csv
echo >> RBS_Objects_$clusterName.csv
printf "\nVMware Done\n"

# Get All Hosts. Windows and Linux:
echo "Physical-Hosts" >> RBS_Objects_$clusterName.csv
curl -X GET "https://$CLUSTER/api/v1/host?operating_system_type=ANY" -H "accept: application/json" -H "authorization: Basic "$hash_password"" -k -s | python -m json.tool | jq -r '.data[] | [.name] + [.operatingSystem] + [.status] | @sh' | column -t -s "'" >> RBS_Objects_$clusterName.csv
echo >> RBS_Objects_$clusterName.csv
printf "Physical Hosts done\n"

# Get All Nutanix VMs:
echo "Nutanix-VMs" >> RBS_Objects_$clusterName.csv
curl -X GET "https://$CLUSTER/api/internal/nutanix/vm?primary_cluster_id=local&is_relic=false" -H "accept: application/json" -H "authorization: Basic "$hash_password"" -k -s | python -m json.tool | jq -r '.data[] | [.name] + [(.agentStatus.agentStatus)] |@sh' | column -t -s "'" >> RBS_Objects_$clusterName.csv
echo >> RBS_Objects_$clusterName.csv
printf "AHV Done\n"

printf "Output available in RBS_Objects_$clusterName.csv(cat/less/Excel) file\n\n"
