# Docker Samba Server

This project creates a Docker container that runs a Samba server based on Alpine
Linux, allowing you to share files with custom users and optional public access.

## Features

- **Lightweight Image**: Based on Alpine Linux for minimal resource usage.
- **Custom User Management**: Create users with personalized directories and access credentials.
- **Public Share Option**: Enable a public folder for anonymous access.
- **Configurable Timezone**: Set the timezone via the `TZ` environment variable, defaulting to `UTC` if not provided.
- **Custom Workgroup**: Define the workgroup for network browsing compatibility.
- **Secure File Sharing**: Uses SMB2 and SMB3 protocols for enhanced security.
- **Automatic Logging**: Outputs logs to `stdout` for easy monitoring.

## How to use this image

```bash
docker run -d \
  -e USERS="user1:password1,user2:password2" \
  -e ENABLE_PUBLIC="true" \
  -e WORKGROUP="TEST" \
  -e TZ="America/New_York" \  # Optional: Specify the timezone
  -p 445:445 -p 139:139 -p 137:137/udp -p 138:138/udp \
  --name samba jamp/samba
```

## Configuration

- USERS: A comma-separated list of users and passwords in the format username:password. Example: user1:password1,user2:password2.
- ENABLE_PUBLIC: Enables a public folder for guest access. Possible values: true or false (default: false).
- WORKGROUP: Defines the Samba workgroup (default: WORKGROUP).
- TZ: Specifies the container's timezone. If not set, the default is UTC.

## Notes

- The container uses the tzdata package to manage timezones.
If the TZ variable is not set, UTC will be used as the default timezone.
- Users specified in USERS will have their personal directories and authenticated access.
- The public folder is enabled only if ENABLE_PUBLIC is set to true.

## CI/CD - Automated Docker Hub Publishing

This repository includes a GitHub Actions workflow that automatically builds and publishes the Docker image to Docker Hub.

### Workflow Triggers

The workflow runs automatically on:
- **Push to main branch**: Builds and pushes with `latest` tag
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
