# Variables
ruleID="8c29a185-7d1b-4b49-b8d9-8145ed4437cf"

# Split to 1000 lines (Cloudflare Free Plan)
wget -O raw.txt "https://raw.githubusercontent.com/lukaskronus/myfilterlist/main/domain/lists/cloudflare-justdomains.txt"
split -l 1000 -d raw.txt blockedList
mkdir -p final
mv blockedList* final/
cd final/

# Remove all lists from Cloudflare Rules
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ID/gateway/rules/$ruleID" \
    -H "X-Auth-Email: $CF_AC" \
    -H "Authorization: $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"name": "Temp", "enabled": true,"action": "block","filters": ["dns"], "traffic": "any(dns.content_category[*] in {1})"}'

# Get current list ID
curl -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ID/gateway/lists" \
    -H "X-Auth-Email: $CF_AC" \
    -H "Authorization: $CF_TOKEN" \
    -H "Content-Type: application/json" >gatewayListJson

# Delete all lists
jq -r -c '.result[].id' gatewayListJson | while read i; do
    curl -X DELETE "https://api.cloudflare.com/client/v4/accounts/$CF_ID/gateway/lists/$i" \
        -H "X-Auth-Email: $CF_AC" \
        -H "Authorization: $CF_TOKEN" \
        -H "Content-Type: application/json"
done

# Make Cloudflare-compatible list files
for tempVar in blockedList*; do
    jq -n '{name: $name, type: $type, items: $items}' --arg name "$tempVar" --arg type "DOMAIN" --argjson items "$(jq -R '[.,inputs] | map({value: .})' $tempVar)" > "$tempVar.json"

    curl -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ID/gateway/lists" \
        -H "X-Auth-Email: $CF_AC" \
        -H "Authorization: $CF_TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary "@${tempVar}.json"

    rm "$tempVar.json"
done

# Get new list IDs
curl -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ID/gateway/lists" \
    -H "X-Auth-Email: $CF_AC" \
    -H "Authorization: $CF_TOKEN" \
    -H "Content-Type: application/json" > gatewayListJson

# Generate new rule
echo -n 'any(dns.content_category[*] in {1})' > rule1.json
jq -r -c '.result[].id' gatewayListJson | while read i; do
    echo -n " or any(dns.domains[*] in $"$i")" >> rule1.json
done
sed '$ s/-//g' rule1.json > rule2.json
rule=$(head -n 1 rule2.json)

# Apply rule
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ID/gateway/rules/$ruleID" \
    -H "X-Auth-Email: $CF_AC" \
    -H "Authorization: $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"name": "Block by Lists", "enabled": true,"action": "block","filters": ["dns"],"traffic": "'"$rule"'"}'
