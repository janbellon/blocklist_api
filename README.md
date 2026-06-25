# Blocklist API
A little IP blocklist database written in Python. \

## Use case
When you have a lot of servers exposed to the internet, it is necessary to have a good vision on the scans and attacks performed on the server and to be able to ban malicious ip addresses. \
This API provides a `/banip` and `/unbanip` webhook endpoints that allow to add and remove ip addresses from a centralized blocklist database. \
Hosts can then run the `sync_blocklist.sh` script to synchronize a local ipset with the global blocklist via a cron job.

## Setup
### Deploy the blocklist api
```bash
git clone https://github.com/janbellon/blocklist_api
```
Generate the bearer tokens for api access
```bash
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
