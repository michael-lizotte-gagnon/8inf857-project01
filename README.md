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
`podman machine init`
`podman machine init MyMachineName` <- should pull default podman image into WSL (if on Windows), or host (if linux)
Then you can check default connection: `podman system connection list`

`podman machine start {NAME}` omit {NAME} if just running from default

### Podman compose
With a machine initialized and started, you can validate the parsed compose.yaml configuration with \
`podman compose -f compose.yaml config`

Then we can finally build the stack with \
`podman compose -f compose.yaml build`

If you get the useless message `no services to build`, it means your podman env isn't setup properly. Recheck that your podman machine
is correctly spun up with Docker-Compose available

### Run the stack
After the configs were validated, run the stack with \
`podman compose -f compose.yaml up` \
It should then start pulling all the images referenced in the `compose.yaml` file (only the first time). Logs should be contained in `/logs` of the current repo

## Snort
Installing Snort is painfull, so I used an already existing image (docker.io/vimagick/snort3:latest)
