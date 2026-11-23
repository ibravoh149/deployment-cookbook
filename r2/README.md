# Cloudflare R2: storage for backups

R2 is Cloudflare's file storage, compatible with Amazon S3 tools. Used here to keep database backups away from
the server, so losing the server (or the whole Oracle account) doesn't lose them.

**Why R2:** free up to 10 GB stored, with no charge for downloading (restoring costs nothing), and a different
company from the server. Oracle's own Object Storage is also free (20 GB), but it sits in the same account as the
server, so it doesn't protect against losing that account.

**Cost in practice:** zero. Database backups for a small app are a few MB each; 30 days of them is well under
100 MB. One upload a day plus hourly checks is a few thousand operations a month, against free allowances of 1
million (writes) and 10 million (reads).

## 1. Turn R2 on

Cloudflare dashboard → **Storage & databases → R2 Object Storage** → **Add R2 subscription to my account**.
It asks for a card even though usage under the free allowance costs $0.00. "10 GB / month" means 10 GB
stored on average over the month, not 10 GB uploaded.

## 2. A bucket

**Create bucket**:

- **Name:** e.g. `<name>-backups`. Permanent: it can't be renamed.
- **Location:** **Automatic** (distance from the server doesn't matter for a small daily upload).
- **Default storage class:** **Standard**.

> **Snag: keep Standard.** The free allowance covers Standard only; *Infrequent Access* is billed separately
> from the first byte, and has a minimum storage time.

**Public access** shows *Disabled*: nobody can read the bucket without a key. Keep it that way.

## 3. Delete old files automatically

The bucket → **Settings → Object Lifecycle Rules → Add**:

- **Rule name:** `delete-after-30-days`
- **Prefix:** empty (the whole bucket)
- **Delete uploaded objects after:** `30` **Days**. Leave the other two actions unticked.
- **Save changes**

Leave the **Default Multipart Abort Rule** that's already there: Cloudflare's own.

> **Snag: "Days specified must be a positive number"** just means the days box is empty.

With R2 deleting old files, the server only ever needs to upload, never delete.

## 4. A key for this bucket only

**R2 Object Storage** (overview) → **Manage API Tokens** → **Create Account API Token**:

| Field | Set to |
|---|---|
| Token name | `<name>-server-backups` |
| Permissions | **Object Read & Write** |
| Specify bucket(s) | **Apply to specific buckets only** → your bucket |
| TTL | **Forever** |
| Client IP Address Filtering | empty |

**Create Account API Token**, then copy the **Access Key ID** and the **Secret Access Key** into a password
manager. **They're shown only once.**

> **Snag: the form's defaults are wrong for this.** It opens on *Object Read only* and *all buckets*. Read only
> can't upload; all buckets would let this key reach every bucket you ever make.

> **Snag: don't filter by IP.** Locking the key to the server's IP blocks restoring from your own computer, and
> an ephemeral server IP can change if the server is rebuilt.

## 5. The endpoint

`https://<account-id>.r2.cloudflarestorage.com`. The account ID is on the R2 overview page (Account Details),
and in the dashboard's address bar: `dash.cloudflare.com/<account-id>/r2/...`.

These four values go in the server's `.env`: see [../backups/](../backups/).

## Checking what's in the bucket

> **Snag: the dashboard's counts lag.** The bucket list and the *Bucket Size* box update periodically, so a new
> bucket shows 0 objects / 0 B for a while even when files are there. The bucket's **Objects** tab is live.

The exact truth, from the server (sizes in bytes, with each file's original time):

```bash
docker compose exec offsite rclone lsl r2:<bucket>
```
