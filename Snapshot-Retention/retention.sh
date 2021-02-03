#!/bin/bash

# Prints usage

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

curl -s -X GET "https://$CLUSTER/api/v1/unmanaged_object" -H "accept: application/json" -H "authorization: Basic "$hash_password"" -k | python -m json.tool | jq -r '.data[] | "\(.name) \(.retentionSlaDomainName) \(.unmanagedStatus) \(.snapshotCount) \(.localStorage) \(.archiveStorage)"' > dataUnmanagedRubrikObjects.txt

echo -e "Name                                                                                        | Availability    | SLA Domain                        |Snapshots | Local Storage  | Archival Storage  " >> UnmanagedObject.csv
echo -e "--------------------------------------------------------------------------------------------+-----------------+-----------------------------------+----------+----------------+-------------------" >> UnmanagedObject.csv

lines=$(cat dataUnmanagedRubrikObjects.txt | wc -l)


for (( i=1; i<=$lines; i++ ))
do
	sla=$(cat dataUnmanagedRubrikObjects.txt | sed -n ""$i"p" | awk '{print $(NF-4)}')
	if [[ "$sla" == "Unprotected" ]]
	then
		slaDomain=Forever
	else
		slaDomain=$(echo $sla)
	fi

	archivalStorage=$(cat dataUnmanagedRubrikObjects.txt | sed -n ""$i"p" | awk '{print $NF}')
	archivalData=$(awk -v m=$archivalStorage 'BEGIN { print ((m / 1000 /1000))}')
	val=$(echo $archivalData | cut -d '.' -f 1)
	if [ "$val" -lt 1000 ]
	then
		archivalDataRev=$(printf %.2f $(awk -v m=$archivalStorage 'BEGIN { print ((m / 1000 / 1000))}'))" MB"
	else
		archivalDataRev=$(printf %.2f $(awk -v m=$archivalData 'BEGIN { print ((m / 1000))}'))" GB"
	fi

	localStorage=$(cat dataUnmanagedRubrikObjects.txt | sed -n  ""$i"p" | awk '{print $(NF-1)}')
	localData=$(awk -v m=$localStorage 'BEGIN { print ((m / 1000 /1000))}')
	val2=$(echo $localData | cut -d '.' -f 1)
	if [ "$val2" -lt 1000 ]
	then
		localDataRev=$(printf %.2f $(awk -v m=$localStorage 'BEGIN { print ((m / 1000 / 1000))}'))" MB"
	else
		localDataRev=$(printf %.2f $(awk -v m=$localData 'BEGIN { print ((m / 1000))}'))" GB"
	fi

	snapshots=$(cat dataUnmanagedRubrikObjects.txt | sed -n ""$i"p" | awk '{print $(NF-2)}')
	objectAvail=$(cat dataUnmanagedRubrikObjects.txt | sed -n ""$i"p" | awk '{print $(NF-3)}')
	name=$( cat dataUnmanagedRubrikObjects.txt | sed -n ""$i"p" | awk '{$(NF)=$(NF-1)=$(NF-2)=$(NF-3)=$(NF-4)=""; print $0}')

	printf " %-90s | %-15s | %-33s | %-8s | %-14s | %-10s \n" "$name" "$objectAvail" "$slaDomain" "$snapshots" "$localDataRev" "$archivalDataRev" >> UnmanagedObject.csv
done

printf "\nData Available in UnmanagedObject.csv\n\n"

rm -f dataUnmanagedRubrikObjects.txt
