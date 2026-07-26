# ALZ Lab — management groups, policy and CI/CD in Bicep

A deliberately small Azure Landing Zone built to run on a trial subscription without consuming the credit. It deploys the full ALZ management group hierarchy, custom policy definitions, an initiative, and scope-differentiated assignments — through a GitHub Actions pipeline with a human approval gate.

Everything in this repo is free to run. No firewall, no gateways, no DDoS plan, no Defender plans, no private DNS zones.

## What gets deployed

```
Tenant Root Group
└── alzlab                     intermediate root — policy anchor
    ├── alzlab-platform
    │   ├── alzlab-identity
    │   ├── alzlab-management
    │   └── alzlab-connectivity
    ├── alzlab-landingzones
    │   ├── alzlab-corp         baseline @ Deny
    │   └── alzlab-online
    ├── alzlab-sandbox          baseline @ Audit
    └── alzlab-decommissioned
```

Plus two custom policy definitions (no anonymous blob access, no public IPs), one built-in (allowed locations), bundled into an initiative and assigned twice with different postures.

## Cost

| Thing | Cost |
|---|---|
| Management groups | Free |
| Policy definitions, initiatives, assignments | Free |
| Compliance evaluation | Free |
| GitHub Actions (public repo) | Free |
| **Everything in this repo** | **$0** |

The ALZ default baseline contains three assignments that are *not* free, and none of them are in here. If you later pull in the full ALZ policy set, disable these first:

- `Deploy-MDFC-Config` — enables Defender for Cloud plans, billed per resource. The silent credit killer.
- `Deploy-Private-DNS-Zones` — ~50 zones at roughly $0.50/month each.
- `Enable-DDoS-VNET` — ~$2,900/month. Would end a $200 credit in about two days.

Set a budget alert at $50 anyway. Budgets are alerts, not caps — your real backstop is the spending limit, which is on by default for trial subscriptions. Leave it on.

## Setup

### 1. Elevate access at tenant root

Tenant-scope deployments and management group creation need Owner at `/`, which nobody has by default.

- Entra ID → Properties → **Access management for Azure resources** → Yes → Save
- This grants you User Access Administrator at `/`
- Assign yourself **Owner** at the root management group properly
- Toggle the elevation **back off**

Skipping the last step is a bad habit to build. Do it properly here and it will be automatic later.

### 2. Create the pipeline identity

```bash
az login
./scripts/setup-oidc.sh <your-github-user>/<repo-name>
```

This creates an app registration with two federated credentials and assigns Owner at tenant root. No client secret is created — the pipeline authenticates via OIDC.

Then add the three printed values as repository **variables** (Settings → Secrets and variables → Actions → Variables).

### 3. Create the protected environment

Settings → Environments → New environment → `alz-lab` → tick **Required reviewers** → add yourself.

That single setting is the approval gate. The `environment: alz-lab` line in the workflow is what makes the deploy job wait for it.

> Required reviewers on a private repo needs a paid GitHub plan. Make the repo public (there are no secrets in it) or drop the reviewer requirement and rely on branch protection alone.

### 4. Protect main

Settings → Rules → New ruleset → require a pull request before merging.

Without this, you can push straight to `main` and the what-if job never runs. The approval gate still fires, but you approve without having seen a plan — which defeats the point.

## Running it

Open a PR. The `whatif` job posts the plan as a PR comment. Merge, and the `deploy` job stops and waits for your approval before touching Azure.

The first PR's policy what-if step will fail — the management groups don't exist yet, so there's no scope to evaluate against. It's marked `continue-on-error` and goes green from the second PR onward.

## The exercises

The deployment is the setup. These are the actual learning:

1. **Watch compliance populate.** Everything deploys with `enforcementMode: DoNotEnforce`. Go to Policy → Compliance and watch results appear over ~15 minutes. Nothing is being blocked yet.

2. **Turn on enforcement.** Run the workflow manually (Actions → alz-lab → Run workflow) with `enforcementMode: Default`. Approve it.

3. **Get blocked.** Move your subscription into `alzlab-corp`, then try to create a storage account with default settings. It gets denied, and the non-compliance message you wrote in `assignments/main.bicep` is what you see.

4. **Move and retry.** Move the same subscription to `alzlab-sandbox` and repeat. Same subscription, same request, different outcome — because the assignment there uses `Audit`. This is the moment inheritance stops being abstract.

5. **Break it on purpose.** Change `allowedLocations` to a region you aren't using, open a PR, and read the what-if output before approving. Notice how little the plan tells you about downstream impact — that gap is why `DoNotEnforce` plus compliance review exists.

6. **Then go further.** Add a `deployIfNotExists` policy (diagnostic settings to a Log Analytics workspace is the classic). It needs `identity: { type: 'SystemAssigned' }` on the assignment plus a role assignment for the remediation identity — a genuine step up in complexity, and the reason ALZ deployments need elevated permissions.

## Teardown

Do this with a week of credit remaining, not on the last day.

```bash
./scripts/teardown.sh alzlab
```

Order matters: subscriptions move out first, then assignments, then definitions, then management groups leaves-first. A management group will not delete while it contains anything at all.

## Notes

- Use a fresh Microsoft account for this. You're granting root-scope access and creating tenant-wide policy in the directory.
- `prefix` becomes part of every management group ID and cannot be renamed after creation — only deleted and recreated. Pick it once.
- Management-group-scoped policy assignment names are capped at 24 characters. This bites the moment you use a longer prefix.
- One template, parameters as data. Do not copy `infra/` to `dev/` and `prod/` — within six months you'd have two handwritten environments that happen to live in Git.
