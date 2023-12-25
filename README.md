# Cloudflare Tunnel Installer (unofficial)
Install and set up Cloudflare Tunnel on a Linux machine, without having to access Cloudflare Dashboard.  
This is particularly useful for automated workflows.  

## How to Use
### Prepare
1. Login to your cloudflare account
2. Go to [API Tokens](https://dash.cloudflare.com/profile/api-tokens)
3. Create Token > Create Custom Token
4. It requires permission to `` Account/Cloudflare Tunnel - Edit `` and `` Zones/<yourzone>/DNS - Edit ``
5. Enter other values as appropriate (Tip: Because the API Key is used only during installation, we strongly recommend that you set the expiration as short as possible)
6. Continue to summary > Create Token, and Copy your API Key
7. Go to [Dashboard Home](https://dash.cloudflare.com/)
8. Go to your website(zone) page
9. In the API section, copy the Zone ID and Account ID (Tip: The API section is located at the bottom right or bottom of the page)

### Install
Execute the following command:  
You will be asked for API Key, Account ID, Zone ID, hostname (e.g. example.srgr0.com), and service (e.g. http://127.0.0.1:8888).  
```
wget https://raw.githubusercontent.com/Srgr0/cloudflaretunnel_installer/main/installer.sh
sudo chmod +x ./installer.sh
sudo ./installer.sh
```
