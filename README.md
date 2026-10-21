# Projet 1 8INF857 - Installation et configuration IDS/IPS

## Tech stack
- [podman](https://podman.io/docs/installation)
- docker-compose/podman-compose (podman compose wraps Docker, so check [installation](https://docs.docker.com/compose/install/) for windows/linux/mac)
- [Snort](https://docs.snort.org/start/installation)
- [Kibana]()
- [ElasticSearch]()

## Podman
Podman is a container manager from RedHat. It's mostly a clone of Docker, but containers run in rootless mode by default. On windows, it installs a machine on WSL, so it needs that feature enabled (Search -> Windows Features -> Enable WSL / Restart)

### Post install (Linux)
Make sure to spin up the podman daemon **for the current user** only, not **root** \
`systemctl --user status podman.socket`
`systemctl --user start podman.socket`

### Post install (Windows)

When installed (with Docker Compose) - Init default machine (or custom) for windows install only
`podman machine init --rootful` <- needs rootful connection to grant NET_ADMIN and NET_RAW (pretty brutal perms by default)
`podman machine init --rootful MyMachineName` <- should pull default podman image into WSL (if on Windows), or host (if linux)
Then you can check default connection: `podman system connection list`

`podman machine start {NAME}` omit {NAME} if just running from default

### Usage on windows

Either switch the default network connection to the rootful one: `podman system connection default <NAME>` \
OR \
Use the `--connection <NAME>` switch BEFORE any underlying podman commands (i.e: `podman --connection <NAME> compose -f compose.yaml --profile enabled up`)

### Podman compose
With a machine initialized and started, you can validate the parsed compose.yaml configuration with \
`podman compose -f compose.yaml config`

Then we can finally build the stack with \
`podman compose -f compose.yaml build`

If you get the useless message `no services to build`, it means your podman env isn't setup properly or you forgot the `--profile enabled` switch. Recheck that your podman machine is correctly spun up with Docker-Compose available and check profiles in `compose.yaml`

### Run the stack
After the configs were validated, run the stack with \
`podman compose -f compose.yaml up` \
It should then start pulling all the images referenced in the `compose.yaml` file (only the first time). Logs should be contained in `/logs` of the current repo

---

## Snort
Installing Snort is painfull, so we use the existing `docker.io/vimagick/snort3:latest` image with a small custom configuration.

### Snort alerts in Kibana

Snort captures packets on the Podman bridge interface `podman1`, rather than
the host-facing `eth0`, so it does not inspect LAN traffic. Checksum validation
is disabled for this bridge capture because captured container packets may
contain offloaded checksums. Snort writes JSON alerts to the shared `snort-logs`
Podman volume, which Logstash reads directly
and indexes in Elasticsearch as `snort-alerts-YYYY.MM.dd`, using the Snort
alert timestamp as `@timestamp`. Syslog-ng also writes a local copy to
`logs/snort-alerts.log`; that copy is not the ingestion source.
Elasticsearch stores its data in a Podman volume so indexed alerts survive
container recreation. When the ingestion pipeline changes, its versioned
sincedb path causes existing alerts in the Snort volume to be indexed again.
Recreate Elasticsearch, Kibana, Snort, and Logstash to apply these changes,
then rerun the importer after Kibana has initialized:

```powershell
podman compose --profile enabled up -d --force-recreate elastic-search kibana snort logstash
podman compose --profile enabled up -d --force-recreate kibana-import
```

The `kibana-import` service waits for Kibana to become ready and imports
`kibana/snort-alerts-dashboard.ndjson` automatically each time the stack starts.
It creates the `snort-alerts-*` data view, a saved search, and a **Snort
Alerts** dashboard showing the alert time, rule, action, protocol, source,
destination, and packet length. The dashboard initially displays the last 30
days. Open Kibana at <http://localhost:5601> to view it.

### Chained CHAR SQL detection

The test-only Node.js endpoint forwards the HTTP `query` parameter directly to
MariaDB. The request uses `PIPES_AS_CONCAT`, chained `CHAR()` calls, and
`PREPARE` to execute the generated command; local SID 1000004 detects the
obfuscated request. This intentionally unvalidated endpoint is for the isolated
lab only. Run it with `.\scripts\trigger-snort-sql-obfuscation.ps1`.

### Triggering the ICMP DoS community signatures

Run the one-shot ICMP test sender:

```powershell
.\scripts\trigger-snort-dos.ps1
```

It sends exactly two crafted packets to the lab target container: one ICMP echo
request matching community SID 221 and one echo reply matching SID 222. This is
a signature test, not a traffic flood. To use a non-default Podman connection,
pass its name with `-Connection`.

### SSH connection-burst detection

The local SID 1000003 alerts when one source sends more than five TCP SYN
packets to port 22 within 30 seconds. This is a connection-rate heuristic; it
cannot determine whether any SSH authentication attempt failed because SSH
encrypts authentication. Run the isolated test client to verify the alert:

```powershell
.\scripts\trigger-snort-ssh-burst.ps1
```

The test makes seven connection attempts to port 22 on the lab target container
and does not try credentials. Pass `-Connection <name>` if using a non-default
Podman connection. Tune the threshold to your normal traffic before using this
rule beyond the lab.

### Triggering Snort port-scan alerts

Run the isolated Nmap test:

```powershell
.\scripts\trigger-snort-port-scan.ps1
```

It performs a SYN scan of ports 1–1024 on the lab `snort-target` only. Snort's
built-in inspector alerts are enabled, and the port-scan inspector watches
`HOME_NET` with lab-friendly TCP thresholds. Nmap runs as a one-shot container
removed afterward. Pass `-Connection <name>` when using a non-default Podman
connection.

### Triggering the SMB traversal signature

Run the isolated test:

```powershell
.\scripts\trigger-snort-smb-traversal.ps1
```

Compose starts a dummy TCP listener on port 139 and a one-shot client that
sends only the byte pattern matched by community SID 534. The script stops the
listener when the test finishes, including when the client or alert check fails.
This is not a real SMB server, does not access files, and does not publish port
139 on the host. Pass `-Connection <name>` when using a non-default Podman
connection.

---
