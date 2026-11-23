# Deployment cookbook

Step-by-step recipes for putting a web app on a server of your own, written while doing it for real. Every
step is something that was actually clicked or typed, and every **Snag** box is something that actually went
wrong along the way.

## What you end up with

A small Linux server, free on Oracle Cloud's Always Free tier, running your app in Docker:

```
phones, browsers ──https──▶ api.example.com (Cloudflare DNS)
                                   │
                    ┌──────────────▼──────────────── Oracle Cloud VM ──┐
                    │  Caddy (https, automatic certificates)           │
                    │    └▶ your app ──▶ Postgres                      │
                    │  backup: a database copy every night             │
                    │  offsite: copies each backup to Cloudflare R2 ───┼──▶ R2 bucket (30 days)
                    └───────────────────────────────────────────────────┘
          GitHub Actions: merge to main → tests → deploy
```

Monthly cost: the domain (about $10 a year). Everything else stays inside free allowances.

## The recipes, in order

| Step | Folder | What it covers | Time |
|---|---|---|---|
| 1 | [oracle/](oracle/) | Account, the server, its public IP, firewalls, SSH, Docker, updates | ~1 h |
| 2 | [cloudflare/](cloudflare/) | Buying the domain, pointing a name at the server | ~15 min |
| 3 | [server-stack/](server-stack/) | The Docker Compose files: app, Postgres, Caddy, backups; first start | ~30 min |
| 4 | [r2/](r2/) | Cloudflare R2: a bucket, auto-deleting old files, a key for one bucket | ~15 min |
| 5 | [backups/](backups/) | Nightly database copies, the off-site copy to R2, restoring | ~20 min |
| 6 | [github-actions/](github-actions/) | Automatic deploys when a change is merged | ~20 min |

Each folder's README stands on its own, but later steps assume the earlier ones.

## Conventions

- `<angle brackets>` are values you fill in: `<server-ip>`, `<your-domain>`, `<account-id>`.
- **Mac** means the computer you manage the server from; **server** means a terminal logged in to it over SSH
  (its prompt looks like `ubuntu@<name>:~$`).
- **Never commit** `.env` files, private keys or API tokens. The examples here have empty `.env.example` files
  for that reason.

## Platforms

Only Oracle Cloud and Cloudflare so far. Other platforms get their own folder when they're done for real.

## Licence

MIT: copy, change and reuse freely. See [LICENSE](LICENSE).
