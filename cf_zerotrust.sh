# Variables
ruleID="38315ba5-f83a-495b-8953-2d95ab54e980"

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
