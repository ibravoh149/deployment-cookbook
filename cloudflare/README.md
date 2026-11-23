# Cloudflare: the domain and DNS

## 1. Buy the domain

Cloudflare dashboard → **Domain Registration → Register Domains**. Cloudflare sells at cost (a `.com` is about
$10 a year) and the domain's DNS is set up in the same account automatically.

Before buying: search the name on the web and in the app stores for anything similar.

## 2. Point a name at the server

Your domain → **DNS → Records → Add record**:

| Type | Name | IPv4 address | Proxy status | TTL |
|---|---|---|---|---|
| A | `api` | `<server-ip>` | **DNS only** (grey cloud) | Auto |

That makes `api.<your-domain>` reach the server. Check from the Mac after a minute:

```bash
dig +short api.<your-domain>      # prints <server-ip>
```

> **Snag: leave the proxy off (grey cloud).** With the orange cloud, Cloudflare sits in front of the server, and
> Caddy's automatic Let's Encrypt certificate and long-lived WebSocket connections need extra settings. "DNS
> only" sends traffic straight to the server, and Caddy handles https on its own.

No domain yet? For testing, `<server-ip-with-dashes>.sslip.io` (e.g. `1-2-3-4.sslip.io`) resolves to the server
and works with Caddy's certificates too.

## 3. Using the domain elsewhere

- **More names on the same server:** another A record (e.g. `app2`), and another block in the
  [Caddyfile](../server-stack/Caddyfile).
- **Email from the domain** (sign-in codes and the like): email services such as Resend or Brevo give you DNS
  records (SPF, DKIM) to add here to verify the domain.
- **R2 storage** lives in the same Cloudflare account: [../r2/](../r2/).
