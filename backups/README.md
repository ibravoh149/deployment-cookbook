# Backups: nightly, off-site, and restoring

Two services in [../server-stack/docker-compose.yml](../server-stack/docker-compose.yml) work as a pair:

| | `backup` | `offsite` |
|---|---|---|
| Runs | every 24 hours | every hour |
| Does | `pg_dump` of the database into `deploy/backups/` on the server | uploads any backup R2 doesn't have yet |
| Keeps | 14 days (deletes older ones on the server) | never deletes; R2's lifecycle rule keeps 30 days |
| Lost with the server? | yes | no |

`offsite` only copies what `backup` made: if backups stop, off-site copies stop too (see "Know when it breaks").

## How the nightly backup works

```sh
while true; do
  until pg_dump -h postgres -U app -Fc app > /backups/.partial; do
    echo "backup failed; trying again in a minute"; sleep 60
  done
  mv /backups/.partial /backups/app-$(date +%F).dump
  find /backups -name 'app-*.dump' -mtime +14 -delete
  sleep 86400
done
```

- **`-Fc`:** Postgres's compressed custom format, restored with `pg_restore`. A small app's database is a few MB.
- **When:** every 24 hours from when the service starts, not at a fixed time. Each start (a reboot, a deploy that
  changes this service) makes a copy straight away. One file per day: a second copy the same day replaces it.
- **Temporary name, then rename:** a failed or half-written dump never appears under a backup's name.
- **Retry every minute:** see the snag below.

> **Snag (seen for real): an empty backup after a reboot.** Writing straight to the final name
> (`pg_dump > app-$(date +%F).dump`) left a **0-byte file** at 03:11 the morning the server was rebooted: at boot
> Docker starts every container at once, the backup ran before Postgres accepted connections, and the shell had
> already created the file. The off-site copy then uploaded that empty file. `depends_on: service_healthy` doesn't
> help: it only applies to `docker compose up`. Hence the temporary name and the retry loop.

## Turning on the off-site copy (server)

After [../r2/](../r2/), add the four values to `.env` (`nano ~/<name>/deploy/.env`):

```
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_BUCKET=<bucket>
R2_ACCESS_KEY_ID=<access key id>
R2_SECRET_ACCESS_KEY=<secret access key>
```

Type the secret straight into the server; don't paste it into chats or commit it. Then:

```bash
docker compose up -d
docker compose logs offsite
```

Expect `Copied (new)` for each backup, then `off-site copy up to date`. Check sizes match:

```bash
ls -la backups/                                       # on the server
docker compose exec offsite rclone lsl r2:<bucket>    # in R2: same sizes
```

The `NOTICE: Config file "/config/rclone/rclone.conf" not found` line is harmless: the settings come from `.env`.

> **Snag: `0 B / 0 B` in the log means an empty file was copied,** not just a quiet summary. Compare sizes as
> above. rclone re-uploads any file whose size differs on its next hourly run; to do it now:
> `docker compose exec offsite rclone copy /backups r2:<bucket> --include 'app-*.dump' -v`
> (expect `Copied (replaced existing)`).

## Restoring

Into the running server, or a fresh one built with [../server-stack/](../server-stack/):

1. **Get a backup file.** From the server's `backups/`, or from R2: the bucket's **Objects** tab → the file →
   **Download** (free on R2), then copy it to the server:
   ```bash
   scp -i ~/.ssh/<name>_oracle app-YYYY-MM-DD.dump ubuntu@<server-ip>:
   ```
2. **Load it** (server):
   ```bash
   cd ~/<name>/deploy
   docker compose stop app
   docker compose exec -T postgres pg_restore -U app -d app --clean --if-exists < ~/app-YYYY-MM-DD.dump
   docker compose start app
   ```
   `--clean --if-exists` replaces what's there with the backup's contents.

**Try a restore once** before you need it, e.g. into a throwaway Postgres on your Mac:

```bash
docker run -d --name restore-test -e POSTGRES_PASSWORD=x -e POSTGRES_USER=app -e POSTGRES_DB=app postgres:16-alpine
sleep 5 && docker exec -i restore-test pg_restore -U app -d app < app-YYYY-MM-DD.dump
docker exec restore-test psql -U app -d app -c '\dt'      # your tables are there
docker rm -f restore-test
```

## By hand, without R2

From your Mac, now and then:

```bash
rsync -az -e "ssh -i ~/.ssh/<name>_oracle" ubuntu@<server-ip>:<name>/deploy/backups/ ./<name>-backups/
```

## Know when it breaks

Nothing above warns you if backups stop (a full disk, a crashed container): both services just go quiet. Worth
adding: a daily check that the newest file in R2 is under 2 days old **and not empty**, sending you a
notification if not. Until then, glance at the bucket's Objects tab once a week.
