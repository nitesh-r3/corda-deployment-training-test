#!/usr/bin/env bash

if ! jq --version >/dev/null 2>&1; then
    echo "jq not present"
    exit 1
fi

if ! az --version >/dev/null 2>&1; then
    echo "az not present"
    exit 1
fi

#ACCOUNT_NAME="Team Professional Services"
RG_NAME="ps-rg-nitesh-arnab-dltledgers"
FILE_NAME="ip_details_$(date '+%s' && echo "$EPOCHSECONDS").csv"
touch "$FILE_NAME"

# set account
#az account set --subscription $ACCOUNT_NAME


echo "Fetching VM List"
VM_LIST=$(az vm list -g ${RG_NAME})

LEN=$(echo "${VM_LIST}" | jq length)

for((i=0;i<"$LEN";i++)); do
    VM_NAME=$(echo "$VM_LIST" | jq '.['"$i"'].name' | tr -d '"')
    IP_ADDRESS_JSON=$(az vm list-ip-addresses -g "$RG_NAME" -n "$VM_NAME")
    echo "Fetching details for VM : $VM_NAME"
    PRIVATE_IP=$(echo "$IP_ADDRESS_JSON" | jq '.[0].virtualMachine.network.privateIpAddresses[0]' | tr -d '"')
    PUBLIC_IP=$(echo "$IP_ADDRESS_JSON" | jq '.[0].virtualMachine.network.publicIpAddresses[0].ipAddress' | tr -d '"')
    echo "${VM_NAME},${PRIVATE_IP},${PUBLIC_IP}" >> "$FILE_NAME"
done

echo "LB Details,," >> "$FILE_NAME"

echo "Fetching LB List"
LB_LIST=$(az network lb list -g ${RG_NAME})
LEN=$(echo "${LB_LIST}" | jq length)

for((i=0;i<"$LEN";i++)); do
    LB_NAME=$(echo "$LB_LIST" | jq '.['"$i"'].name' | tr -d '"')
    echo "Fetching details for LB : $LB_NAME"
    PUBLIC_IP_IDS=$(az network lb show -g ${RG_NAME} -n "$LB_NAME" --query "frontendIpConfigurations[].publicIpAddress.id" --out tsv)
    LB_PUBLIC_IP=$(az network public-ip show --ids "$PUBLIC_IP_IDS" | jq '.ipAddress' | tr -d '"')
    
    echo "${LB_NAME},,${LB_PUBLIC_IP}" >> "$FILE_NAME"
done



echo "Fetching SQL DB Details"

SQL_SERVER_LIST=$(az sql server list -g ${RG_NAME})
LEN=$(echo "${SQL_SERVER_LIST}" | jq length)
for((i=0;i<"$LEN";i++)); do

    

    SQL_SERVER_NAME=$(echo "$SQL_SERVER_LIST" | jq '.['"$i"'].name' | tr -d '"')
    
    echo "Fetching details for server $SQL_SERVER_NAME"

    SQL_DB_LIST=$(az sql db list --resource-group "$RG_NAME" --server "$SQL_SERVER_NAME")

    DB_LEN=$(echo "$SQL_DB_LIST" | jq length)
    

    for((j=0;j<"$DB_LEN";j++)); do
        
        DB_NAME=$(echo "$SQL_DB_LIST" | jq '.['"$j"'].name' | tr -d '"')
        

        if [[ "${DB_NAME}" != "master" ]]; then
            echo "Writing DB Details ${DB_NAME}"
            CONN_STRING=$(az sql db show-connection-string --server "$SQL_SERVER_NAME" -n "$DB_NAME" -c jdbc)
            echo "$SQL_SERVER_NAME,$DB_NAME,$CONN_STRING" >> $FILE_NAME
            
        fi
                
    done
    
done





