# Oracle Cloud: a free server

An Arm server (Ampere A1) on Oracle's **Always Free** tier: 2 cores and 12 GB of memory here, out of a free
allowance of 4 cores and 24 GB, so half is left for another app. Ubuntu 24.04.

## 1. An SSH key (Mac)

The key you'll log in with. Name it after the server, so you know what it's for later.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/<name>_oracle -C "<name> oracle"
pbcopy < ~/.ssh/<name>_oracle.pub     # copies the public half, the part you give Oracle
```

The file without `.pub` is the private key: it never leaves your Mac.

## 2. The account

1. Sign up at **cloud.oracle.com** (free tier).
2. Pick a **home region** close to you or your users. Always Free resources exist only in the home region, and
   it **can't be changed later**. Distance matters less than you'd think for an app that isn't real-time: from
   Frankfurt, most of Africa is 50–200 ms away.
3. A card is needed for the identity check. Free-tier resources aren't charged.
4. Wait for the "account ready" email before creating anything.

## 3. The server

Menu (☰) → **Compute → Instances → Create instance**. On the form, top to bottom:

1. **Name:** your app's name.
2. **Compartment:** leave the root one.
3. **Availability domain:** leave the default. AD 1, AD 2 and AD 3 are separate data centres in the same region,
   equal in every way that matters here; the number isn't a ranking. The only reason to switch is
   "out of capacity" (below).
4. **Advanced options → capacity:** leave **On-demand**. Not *Preemptible*: Oracle can switch those off.
5. **Shape first:** **Change shape → Virtual machine → Ampere → VM.Standard.A1.Flex**, **2 OCPUs**, **12 GB**.
   Choose the shape before the image, so the image list only shows images that fit it.
6. **Image:** **Change image → Ubuntu → Canonical Ubuntu 24.04** (not "Minimal").
7. **Networking:** **Create new virtual cloud network** and **Create new public subnet** (defaults are fine).
   Turn on **Assign a public IPv4 address** if it lets you; see the snag below if it doesn't.
8. **SSH keys:** **Paste public keys**, and paste the key from step 1.
9. **Boot volume:** defaults.
10. Review, then **Create**. It goes from *Provisioning* to *Running* in a minute or two.

> **Snag: "Out of capacity".** Free Ampere servers are popular. Go back, pick another availability domain, and
> create again; or try later.

> **Snag: the public IPv4 switch is greyed out** when the subnet is created in the same form. Create the server
> anyway, then add the address (step 4). Ignore the "Connect public subnet to internet" quick action you may be
> offered: the new network already has an internet gateway and a route; all it would add is an empty extra
> firewall (a network security group) you don't need.

## 4. Its public IP address

Instance page → **Networking** → **Attached VNICs** → the primary VNIC → **IP administration** (or *IPv4
addresses*) → the `10.0.0.x` row → **⋮ → Edit** → **Ephemeral public IP** → **Update**. The row now shows the
public address: that's `<server-ip>`.

An ephemeral IP stays through restarts and lasts as long as the instance. If you want an address that outlives
the server (to rebuild it without changing DNS), use a **Reserved public IP** instead.

## 5. Open ports 80 and 443

Two firewalls, and both need it.

**Oracle's (the security list).** Networking → Virtual cloud networks → your VCN → **Security** → the default
security list → **Add Ingress Rules**: source `0.0.0.0/0`, TCP, destination port `80`. Again for `443`. (Port 22
for SSH is already there.)

**The server's own.** Log in (Mac):

```bash
ssh -i ~/.ssh/<name>_oracle ubuntu@<server-ip>
```

Then on the server:

```bash
sudo iptables -L INPUT -n --line-numbers      # find the line number of the REJECT rule
sudo iptables -I INPUT 5 -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 5 -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save                # keeps them after a reboot
sudo iptables -L INPUT -n --line-numbers      # check: 80 and 443 ACCEPT, above REJECT
```

> **Snag: rules inserted below REJECT do nothing.** Rules are read top to bottom and stop at the first match,
> so ACCEPT must come above REJECT. On a fresh Ubuntu 24.04 image REJECT is line 5, so insert at 5 (which pushes
> it down). Inserting at 6 puts them after REJECT. If that happened: `sudo iptables -D INPUT <line>` for each,
> and insert again at the right number.

## 6. Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
exit        # log out and back in, so the new group applies
```

> **Snag: `permission denied ... docker.sock`.** The group change only applies to new logins. Log out and in
> again; `groups` should list `docker`.

## 7. Updates and restarts

Right after setup, and now and then:

```bash
sudo apt update && sudo apt upgrade -y
ls /var/run/reboot-required 2>/dev/null && echo "restart needed" || echo "no restart needed"
sudo reboot        # if needed; SSH drops, the server is back in about a minute
```

After a reboot, Docker starts the containers by itself (`restart: unless-stopped` in the Compose file) and the
firewall rules come back (saved with `netfilter-persistent`). Check with `docker compose ps`.

> **Snag: after a reboot, Docker starts every container at once.** `depends_on: condition: service_healthy` only
> applies to `docker compose up`, not to Docker's own restart at boot. A job that needs the database on its first
> run (like the backup) must retry. See [../backups/](../backups/).

## Good to know

- **Idle reclamation:** Oracle may reclaim Always Free instances that stay nearly idle for a long time. Check
  their current terms; off-site backups ([../backups/](../backups/)) are what you'd rebuild from.
- **What's left free:** 2 more Ampere cores and 12 GB (a second server, or more for this one), and two small
  **VM.Standard.E2.1.Micro** servers (1 GB each, AMD, offered only in some availability domains), handy for a
  staging server. One server can also host several apps, each with its own domain: Caddy serves them all.
