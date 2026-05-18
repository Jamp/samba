# Docker Samba Server

This project creates a Docker container that runs a Samba server based on Alpine
Linux, allowing you to share files with custom users and optional public access.

## Features

- **Lightweight Image**: Based on Alpine Linux for minimal resource usage.
- **Custom User Management**: Create users with personalized directories and access credentials.
- **Public Share Option**: Enable a public folder for anonymous access.
- **Time Machine Support**: Native Apple Time Machine backup support with automatic configuration.
- **Avahi mDNS/DNS-SD**: Automatic service discovery for seamless macOS integration.
- **Configurable Timezone**: Set the timezone via the `TZ` environment variable, defaulting to `UTC` if not provided.
- **Custom Workgroup**: Define the workgroup for network browsing compatibility.
- **NetBIOS Name**: Set a friendly name that appears in macOS Finder and Windows Network.
- **Secure File Sharing**: Uses SMB2 and SMB3 protocols for enhanced security.
- **Automatic Logging**: Outputs logs to `stdout` for easy monitoring.

## How to use this image

```bash
docker run -d \
  -e USERS="user1:password1,user2:password2" \
  -e ENABLE_PUBLIC="true" \
  -e ENABLE_TIMEMACHINE="true" \
  -e WORKGROUP="TEST" \
  -e NETBIOS_NAME="MY-NAS" \
  -e TZ="America/New_York" \
  -p 445:445 -p 139:139 -p 137:137/udp -p 138:138/udp -p 5353:5353/udp \
  -v /srv/disk0/home:/homes \
  -v /srv/disk0/public:/public \
  -v /srv/disk0/timemachine:/timemachine \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE --cap-add=SETUID --cap-add=SETGID \
  --cap-add=CHOWN --cap-add=DAC_OVERRIDE --cap-add=FOWNER \
  --cap-add=SYS_CHROOT --cap-add=NET_RAW \
  --security-opt no-new-privileges:true \
  --name samba jamp/samba
```

## Security hardening

This image runs Samba with a minimal set of Linux capabilities (everything dropped except those Samba actually needs) and the `no-new-privileges` flag. This shrinks the attack surface significantly compared to a default Docker container running as root with the full capability set.

| Capability | Why Samba needs it |
|------------|-------------------|
| `NET_BIND_SERVICE` | Bind to privileged ports 139/445 |
| `SETUID` / `SETGID` | `smbd` forks and switches to the authenticated user per connection |
| `CHOWN` | Create user home directories with the correct owner |
| `DAC_OVERRIDE` | Access files owned by different uids when serving shares |
| `FOWNER` | `chmod`/`chown` operations on shared files |
| `SYS_CHROOT` | `smbd` chroots into each share per connection |
| `NET_RAW` | Required by `avahi-daemon` for mDNS broadcast |

> **Note:** A truly *non-root* Samba is impractical because `smbd` must `setuid()` to the authenticated user on every connection. Dropping all but the required capabilities is the realistic hardening for this workload. See the `docker-compose.yaml` for the recommended setup.

## Configuration

- **USERS**: A comma-separated list of users and passwords in the format `username:password`. Example: `user1:password1,user2:password2`.
- **ENABLE_PUBLIC**: Enables a public folder for guest access. Possible values: `true` or `false` (default: `false`).
- **ENABLE_TIMEMACHINE**: Enables Apple Time Machine support. Possible values: `true` or `false` (default: `false`). When enabled, all users will have access to the Time Machine share.
- **WORKGROUP**: Defines the Samba workgroup (default: `WORKGROUP`).
- **NETBIOS_NAME**: Sets the friendly server name displayed in macOS Finder and Windows Network browser. If not set, defaults to the `WORKGROUP` value.
- **TZ**: Specifies the container's timezone. If not set, the default is `UTC`.

## Volumes & Data Persistence

To persist data across container restarts you **must** mount host directories into the container. Without volumes, data lives on the container's writable layer and is lost when the container is recreated.

| Container path | Purpose | Required when |
|----------------|---------|---------------|
| `/homes`       | Base directory containing one subdirectory per user from `USERS` (e.g. `/homes/jamp`, `/homes/maria`) | Always recommended |
| `/public`      | Public share (guest access)                                              | `ENABLE_PUBLIC=true` |
| `/timemachine` | Apple Time Machine backup target                                         | `ENABLE_TIMEMACHINE=true` |

### How user homes work

All user home directories live under a single base path inside the container: `/homes/<username>`. You only need to mount **one** host directory to `/homes` and every user defined in `USERS` will get an automatically created subdirectory there.

For example, with `USERS=jamp:secret,maria:secret` and `/srv/disk0/home:/homes` mounted:

```
Host                          Container
/srv/disk0/home/         <->  /homes/
├── jamp/                <->  ├── jamp/      (Samba share [jamp])
└── maria/               <->  └── maria/     (Samba share [maria])
```

The container creates each subdirectory, the Linux user, and sets ownership (`username:username`) and permissions (`770`) on first start, so the host directory can be empty.

> **Tip:** Create the parent directory on the host before starting the container (e.g. `sudo mkdir -p /srv/disk0/home`). Docker creates the per-user subdirectories automatically when the volume is mounted.

### docker-compose example

```yaml
services:
  samba:
    image: jamp/samba
    container_name: samba
    restart: unless-stopped
    environment:
      - NETBIOS_NAME=NAS
      - WORKGROUP=WORKGROUP
      - ENABLE_PUBLIC=true
      - ENABLE_TIMEMACHINE=true
      - TZ=America/New_York
      - USERS=jamp:secret1,maria:secret2
    ports:
      - 139:139
      - 445:445
      - 5353:5353/udp
    volumes:
      - /srv/disk0/home:/homes
      - /srv/disk0/public:/public
      - /srv/disk0/timemachine:/timemachine
```

Or with an `.env` file for portability:

```bash
# .env
HOMES_DIR=/srv/disk0/home
SHARE=/srv/disk0/public
TIME_MACHINE=/srv/disk0/timemachine
```

```yaml
volumes:
  - ${HOMES_DIR}:/homes
  - ${SHARE}:/public
  - ${TIME_MACHINE}:/timemachine
```

## Notes

- The container uses the tzdata package to manage timezones. If the `TZ` variable is not set, `UTC` will be used as the default timezone.
- Users specified in `USERS` will have their personal directories and authenticated access.
- The public folder is enabled only if `ENABLE_PUBLIC` is set to `true`.
- Time Machine support is enabled only if `ENABLE_TIMEMACHINE` is set to `true`. When enabled:
  - All users configured in the `USERS` variable will have access to the Time Machine share.
  - You must mount a volume to `/timemachine` to persist backup data.
  - The share will be hidden from browsing but discoverable by Time Machine.
  - No size limit is set by default (`fruit:time machine max size = 0`), meaning it will use all available space.

## Time Machine Setup

To use Time Machine with this container:

1. Enable Time Machine in your `docker-compose.yaml` or `docker run` command by setting `ENABLE_TIMEMACHINE=true`.
2. Mount a volume for Time Machine backups (e.g., `-v /path/to/backups:/timemachine`).
3. On your Mac, open **System Preferences** → **Time Machine**.
4. Click **Select Disk** and choose the `TimeMachine` share from the network.
5. Authenticate with any user credentials configured in the `USERS` variable.
6. Time Machine will automatically start backing up to the network share.

## CI/CD - Automated Docker Hub Publishing

This repository includes a GitHub Actions workflow that automatically builds and publishes the Docker image to Docker Hub.

### Workflow Triggers

The workflow runs automatically on:
- **Push to master branch**: Builds and pushes with `latest` tag
- **Tag creation** (e.g., `v1.0.0`): Builds and pushes with version tags
- **Manual trigger**: Can be triggered manually from GitHub Actions tab

### Required GitHub Secrets

To enable automatic publishing, configure these secrets in your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add the following secrets:

| Secret Name | Description |
|------------|-------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token (create at https://hub.docker.com/settings/security) |

### Multi-Architecture Support

The workflow builds images for:
- `linux/amd64` (Intel/AMD processors)
- `linux/arm64` (ARM processors, including Apple Silicon)

## Contributions and License

Contributions and improvements are welcome. [Github Repo](https://github.com/Jamp/samba)
