# Deploying Weakty

Server: `weakty@100.104.105.83`
Deploy path: `/home/weakty/server/docker/weakty/`

---

## First Deploy

### 1. Generate secrets (run locally)

```sh
mix phx.gen.secret
```

Run this twice — one value for `SECRET_KEY_BASE`, one for `TOKEN_SIGNING_SECRET`.

### 2. Create `.env` on the server

```sh
ssh weakty@100.104.105.83
mkdir -p /home/weakty/server/docker/weakty
cat > /home/weakty/server/docker/weakty/.env << 'EOF'
SECRET_KEY_BASE=<paste first secret>
TOKEN_SIGNING_SECRET=<paste second secret>
PHX_HOST=yourdomain.com
EOF
```

### 3. Rsync the codebase + database

From your local machine:

```sh
rsync -av \
  --exclude='_build/' \
  --exclude='deps/' \
  --exclude='.env' \
  --exclude='priv/static/uploads/' \
  /Users/ty/Sync/PARA/projects/development/weakty4/ \
  weakty@100.104.105.83:/home/weakty/server/docker/weakty/
```

This syncs `weakty.db` alongside the code. Docker bind-mounts it directly into the container — no volume setup needed.

### 4. Set up Caddy

Install Caddy on the server if not already done:
```sh
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install caddy
```

Create `/etc/caddy/Caddyfile`:

```
yourdomain.com {
    reverse_proxy localhost:4000
}
```

Caddy automatically handles HTTPS and sets `X-Forwarded-Proto: https`, which the app's `force_ssl` config needs.

```sh
sudo systemctl reload caddy
```

### 5. Build and start

```sh
mise run deploy:init
```

Watch logs to confirm startup:
```sh
mise run deploy:logs
```

---

## Subsequent Deploys

```sh
mise run deploy
```

The database is excluded — it lives on the server and the app writes to it in place. Migrations run automatically at startup.

---

## Useful commands

```sh
# Tail logs
mise run deploy:logs

# Pull a backup of the DB
mise run deploy:db:pull

# Restart without rebuild
ssh weakty@100.104.105.83 "cd /home/weakty/server/docker/weakty && docker compose restart"
```

## Uploads

User uploads (`priv/static/uploads/`) are stored in a Docker named volume (`weakty_uploads`) and survive rebuilds automatically.
