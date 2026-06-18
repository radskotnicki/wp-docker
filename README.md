# wp-docker

> Local WordPress development environment powered by Docker — clone any production site to your machine in minutes.

![PHP](https://img.shields.io/badge/PHP-8.0–8.4-777BB4?logo=php&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-latest-21759B?logo=wordpress&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-required-2496ED?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What is this?

**wp-docker** is a minimal Docker Compose setup that lets you run a full WordPress environment locally — including WP-CLI and Composer out of the box. It's designed for developers who need to mirror a production site locally for debugging, development, or testing.

Three workflows supported:

| Workflow | Description |
|---|---|
| **Fresh install** | Spin up a clean WordPress instance |
| **Import from dump** | Restore from a database dump + wp-content backup |
| **Pull from server** | Fetch everything directly from a remote server via SSH |

---

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose plugin)
- `rsync` for server pull — `brew install rsync` on macOS
- SSH access to your server (for the pull workflow)

---

## Quick start

```bash
git clone https://github.com/radskotnicki/wp-docker.git
cd wp-docker
make setup
```

The interactive wizard guides you through the entire setup — no manual config needed.

---

## Setup wizard

Run `make setup` and choose a workflow:

### 1. Fresh WordPress

Spins up a clean WordPress instance. Open `http://localhost:8080` and complete the browser installer.

### 2. Import existing site

Restore from a local backup:

```
data/
├── dump.sql        ← database export (or dump.sql.gz)
└── wp-content/     ← themes, plugins, uploads
```

The wizard imports the database and replaces production URLs automatically.

### 3. Pull from remote server *(recommended)*

Connects to your server via SSH, auto-detects WordPress installations, reads database credentials from `wp-config.php`, and pulls everything down in one step.

```
? SSH connection (user@host): deploy@mysite.com
→ Testing SSH connection... ✓
→ Found WordPress at /var/www/html
? What to pull?
  1) Everything (files + database)
  2) Files only (wp-content)
  3) Database only
```

No manual exports needed.

---

## Manual commands

If you prefer not to use the wizard:

```bash
# Start / stop
make up
make down

# Pull from server manually
make pull SERVER=user@host WP_PATH=/var/www/html

# Import database from data/dump.sql
make import-db

# Replace production URLs with local
make replace-urls OLD=https://example.com

# Run any WP-CLI command
make wp -- plugin list
make wp -- user update admin --user_pass=newpassword
make wp -- cache flush

# Run Composer
make composer -- install --working-dir=/var/www/html/wp-content/themes/my-theme

# Follow logs
make logs
```

---

## Configuration

Copy `.env.example` to `.env` and adjust:

```bash
cp .env.example .env
```

| Variable | Default | Description |
|---|---|---|
| `WP_PORT` | `8080` | Local port for WordPress |
| `PHP_VERSION` | `8.2` | PHP version (8.0, 8.1, 8.2, 8.3, 8.4) |
| `MYSQL_VERSION` | `8.0` | MySQL version (5.7, 8.0, 8.4) |
| `MYSQL_DATABASE` | `wordpress` | Database name |
| `MYSQL_USER` | `wp` | Database user |
| `MYSQL_PASSWORD` | — | Database password |
| `MYSQL_ROOT_PASSWORD` | — | MySQL root password |

After changing `PHP_VERSION`, rebuild the image:

```bash
make build
make down && make up
```

After changing `XDEBUG_ENABLE`, rebuild the image:

```bash
# .env
XDEBUG_ENABLE=true

make build
make down && make up
```

Xdebug listens on port `9003`. Configure your editor:

<details>
<summary>VS Code — launch.json</summary>

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "pathMappings": {
        "/var/www/html/wp-content": "${workspaceFolder}/data/wp-content"
      }
    }
  ]
}
```

Install the [PHP Debug extension](https://marketplace.visualstudio.com/items?itemName=xdebug.php-debug) first.
</details>

<details>
<summary>PhpStorm</summary>

Settings → PHP → Debug → Xdebug port: `9003`

Add a server: host `localhost`, port `8080`, path mapping:
- `/var/www/html/wp-content` → `data/wp-content`
</details>

---

After changing `MYSQL_VERSION`, recreate the database volume:

```bash
make clean   # WARNING: deletes local database
make up
```

---

## Project structure

```
wp-docker/
├── .env.example        # configuration template
├── docker-compose.yml  # WordPress + MySQL services
├── Dockerfile          # WordPress image with WP-CLI + Composer
├── Makefile            # all commands
├── setup.sh            # interactive setup wizard
└── data/
    ├── dump.sql        # database import (gitignored)
    └── wp-content/     # themes, plugins, uploads (gitignored)
```

---

## Troubleshooting

**White screen / database connection error**
```bash
make logs
docker compose ps
```

**Missing styles or images**
```bash
chmod -R 755 data/wp-content
```

**Too many redirects**
```bash
make wp -- option get siteurl
make wp -- option get home
# Both should show http://localhost:8080
```

**Can't log in to wp-admin**
```bash
make wp -- user update admin --user_pass=newpassword
```

---

## License

MIT — use it, fork it, ship it.
