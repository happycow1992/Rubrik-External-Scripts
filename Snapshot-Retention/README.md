# Overview:

Prints all objects under snapshot retention minus the location info.


# Requirements: 

jq - a lightweight and flexible command-line JSON processor.

openssl - create the Base64 encoding of username:password used for authentication

curl - call the Rubrik CDM RESTful API

# Usage: 

`./retension.sh -c "Rubrik-node-IP" -u "Username" -p "Password" <optional>`
