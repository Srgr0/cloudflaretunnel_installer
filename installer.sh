#!/bin/bash -eu

read -p "Enter your Cloudflare API key: " cf_apikey;
read -p "Enter your Cloudflare Account ID: " cfaccount_id;
read -p "Enter your Cloudflare Zone ID: " cfzone_id;
read -p "Enter the hostname: (e.g. example.srgr0.com)" hostname;
read -p "Enter the service: (e.g. http://127.0.0.1:8888)" service;

# check architecture
arch=$(uname -m)
if [[ "$arch" != "x86_64" && "$arch" != "i386" && "$arch" != "i686" && "$arch" != "armv6l" && "$arch" != "armv7l" && "$arch" != "aarch64" ]]; then
    echo "Unsupported architecture: $arch"
    exit 1
fi

# verify apikey
response=$(curl -s -X GET -w "%{http_code}" \
           -H "Authorization: Bearer $cf_apikey" \
           -H "Content-Type: application/json" \
           "https://api.cloudflare.com/client/v4/user/tokens/verify");

# install jq
apt install jq -y

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
case $arch in
    x86_64)
        echo "Architecture: 64-bit (amd64)"
        wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
        sudo dpkg -i cloudflared-linux-amd64.deb
        ;;

    i386 | i686)
        echo "Architecture: 32-bit (x86)"
        wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386.deb
        sudo dpkg -i cloudflared-linux-386.deb
        ;;

    armv6l | armv7l)
        echo "Architecture: ARM"
        wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm.deb
        sudo dpkg -i cloudflared-linux-arm.deb
        ;;

    aarch64)
        echo "Architecture: ARM64 (aarch64)"
        wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
        sudo dpkg -i cloudflared-linux-arm64.deb
        ;;
esac

sudo cloudflared service install $cftunnel_token;
