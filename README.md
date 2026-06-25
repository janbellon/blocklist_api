# Blocklist API
A little IP blocklist database written in Python. \

## Use case
When you have a lot of servers exposed to the internet, it is necessary to have a good vision on the scans and attacks performed on the server and to be able to ban malicious ip addresses. \
This API provides a `/banip` and `/unbanip` webhook endpoints that allow to add and remove ip addresses from a centralized blocklist database. \
Hosts can then run the `sync_blocklist.sh` script to synchronize a local ipset with the global blocklist via a cron job.

## Setup
### Deploy the blocklist api
```bash
export VERSION=v0.1.0
wget https://github.com/janbellon/blocklist_api/releases/download/${VERSION}/docker-compose.yml
wget https://github.com/janbellon/blocklist_api/releases/download/${VERSION}/create_secrets.sh
```
Generate the bearer tokens for api access
```bash
chmod +x create_secrets.sh
./create_secrets.sh
```
Launch
```bash
docker compose up -d
```

### Create sync cronjob on the hosts
```bash
git clone https://github.com/janbellon/blocklist_api /opt/blocklist
cd /opt/blocklist
```
Change the `blocklist_sync.env` environment file
```bash
API_URL=http://your-api-endpoint:8000
TOKEN=readonlytoken
```
Initiate the iptables rules
```bash
./iptables.sh
```
Create the cronjob
```bash
crontab sync.cron
```

### Cli tools
Some bash cli tools have been created to manage the blocked ips manually.

Download the client
```bash
export VERSION=v0.1.0
wget https://github.com/janbellon/blocklist_api/releases/download/${VERSION}/cli.sh
```

Create the env variables for api connection
```bash
export API_URL=http://...
export TOKEN=abcd123
```

Ban an IP
```bash
./cli.sh ban 1.2.3.4
```

Unban an IP
```bash
./cli.sh unban 1.2.3.4
```

List banned ips
```bash
./cli.sh list
```
