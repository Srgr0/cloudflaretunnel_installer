#!/bin/bash -eu

read -p "Enter your Cloudflare API key: " cf_apikey;
read -p "Enter your Cloudflare Account ID: " cfaccount_id;
read -p "Enter your Cloudflare Zone ID: " cfzone_id;
read -p "Enter the hostname: (e.g. example.srgr0.com)" hostname;
read -p "Enter the service: (e.g. http://127.0.0.1:8888)" service;

# verify apikey
response=$(curl -s -X GET -w "%{http_code}" \
           -H "Authorization: Bearer $cf_apikey" \
           -H "Content-Type: application/json" \
           "https://api.cloudflare.com/client/v4/user/tokens/verify");

if [ "$response" -ne 200 ]; then
    echo "Invalid API key.";
    exit 1;
fi

# create a cf tunnel
cftunnel_name="Misskey_$(date +%Y-%m-%d-%H-%M-%S)";
create_tunnel_response=$(curl -s -X POST \
                         -H "Authorization: Bearer $cf_apikey" \
                         -H "Content-Type: application/json" \
                         --data "{\"name\":\"$cftunnel_name\",\"config_src\":\"cloudflare\"}" \
                         "https://api.cloudflare.com/client/v4/accounts/$cfaccount_id/cfd_tunnel");

cftunnel_id=$(echo $create_tunnel_response | jq -r '.result.id');

create_dns_record_response=$(curl --request POST \
                                 --url https://api.cloudflare.com/client/v4/zones/$cfzone_id/dns_records \
                                 -H "Authorization: Bearer $cf_apikey" \
                                 -H "Content-Type: application/json" \
                                 --data "{\"type\":\"CNAME\",\"proxied\":true,\"name\":\"$hostname\",\"content\":\"$cftunnel_id.cfargotunnel.com\"}"
);


update_tunnel_response=$(curl --request PUT \
                          --url https://api.cloudflare.com/client/v4/accounts/$cfaccount_id/cfd_tunnel/$cftunnel_id/configurations \
                          -H "Authorization: Bearer $cf_apikey" \
                          -H "Content-Type: application/json" \
                          --data "{\"config\":{\"ingress\":[{\"hostname\":\"$hostname\",\"service\":\"$service\"},{\"service\":\"http_status:404\"}]}}"
);

get_token_response=$(curl -s -X GET \
                          --url https://api.cloudflare.com/client/v4/accounts/$cfaccount_id/cfd_tunnel/$cftunnel_id/token \
                          -H "Authorization: Bearer $cf_apikey" \
                          -H "Content-Type: application/json" \
);

cftunnel_token=$(echo $get_token_response | jq -r '.result');

# install cf tunnel
read -p "Are you on an ARM system? (y/n): " is_arm;
if [ "$is_arm" = "y" ]; then
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb;
    sudo dpkg -i cloudflared-linux-arm64.deb;
else
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb;
    sudo dpkg -i cloudflared-linux-amd64.deb;
fi

sudo cloudflared service install $cftunnel_token;
