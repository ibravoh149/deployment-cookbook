# GitHub Actions: deploy on merge

Merging a pull request into `main` runs the checks, and if they pass, deploys to the server. Pull requests run
the checks only, so you see whether a change passes before merging. A **Run workflow** button redeploys without a
code change.

The files: [deploy.yml](deploy.yml) (goes in `.github/workflows/`) and [deploy.sh](deploy.sh) (goes in
`scripts/`). The script also works by hand from your Mac.

**Cost:** free for public repos; private repos get 2,000 free minutes a month, and a run takes a few minutes.

## 1. A key just for GitHub (Mac)

A separate key, so it can be revoked without touching yours. No passphrase: the workflow can't type one.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/<name>_deploy -N "" -C "github-actions-deploy"
cat ~/.ssh/<name>_deploy.pub | ssh -i ~/.ssh/<name>_oracle ubuntu@api.<your-domain> 'cat >> ~/.ssh/authorized_keys'
ssh -i ~/.ssh/<name>_deploy ubuntu@api.<your-domain> echo "deploy key works"
```

## 2. Secrets on GitHub (Mac)

```bash
gh secret set DEPLOY_SSH_KEY < ~/.ssh/<name>_deploy
ssh-keyscan -t ed25519 api.<your-domain> | gh secret set DEPLOY_KNOWN_HOSTS
gh secret list        # both listed
```

`DEPLOY_KNOWN_HOSTS` pins the server's identity, so the workflow only ever talks to your server.

> **Snag: `HTTP 404` from `gh secret set`** with two GitHub accounts signed in: the active one can't see the
> repo. `gh auth status` shows which is active; `gh auth switch --user <owner>` fixes it.

> **Snag: running the commands out of order.** `gh secret set DEPLOY_SSH_KEY < ~/.ssh/<name>_deploy` before the
> key exists fails; `ssh-keygen` over an existing file asks to overwrite (answer `y` only if nothing uses it yet).
> Re-run the steps in order; each one is safe to repeat.

## 3. The workflow

Copy [deploy.yml](deploy.yml) to `.github/workflows/deploy.yml` and adjust:

- `paths:` the folders whose changes should deploy (a docs-only change shouldn't).
- The `check` job: your project's install, type check and tests. It can start a throwaway Postgres for tests.
- `environment: production`: optionally, GitHub → Settings → Environments → production → **Required
  reviewers**, to approve each deploy by hand.

## 4. Working this way

1. Make changes on a branch; open a pull request. The checks run on it.
2. Merge it. The checks run again on `main`, then the deploy.
3. Watch it: the repo's **Actions** tab, or `gh run watch`.

Optional: Settings → Branches → a rule for `main` requiring a pull request and the check, so nothing reaches the
server without passing.

**To stop GitHub deploying:** remove the key's line from `~/.ssh/authorized_keys` on the server.
