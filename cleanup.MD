# 🧨 Quest: Tear It All Down

Run this once you're done testing. The repo stays on GitHub for next time —
this only kills the live Azure resources (VMs, Dev Center, Project, Catalog).

## ☐ Step 1 — Delete the environment first (kills the VMs/cost)
Fastest way: **Dev Center Developer Portal** → your environment → **Delete**.

Or via CLI:
```bash
az devcenter dev environment delete \
  --dev-center-name nexedge-devcenter \
  --project-name <your-project-name> \
  --environment-name <your-environment-name> \
  --user-id me \
  --yes
```
> Don't know the exact names? List them first:
> `az devcenter dev environment list --dev-center-name nexedge-devcenter --project-name <your-project-name> --user-id me -o table`

## ☐ Step 2 — Confirm the resource group is actually empty
The environment delete should remove every VM, NIC, public IP, disk and the
VNet/NSG. Double-check nothing got orphaned (stuck disks/IPs are the usual
silent cost leak):
```bash
az resource list --resource-group <env-resource-group-name> -o table
```
If anything's left, delete the resource group outright:
```bash
az group delete --name <env-resource-group-name> --yes --no-wait
```

## ☐ Step 3 — Remove the Project → Environment type link
Portal: Dev Center → **Projects** → your project → **Environment types** →
delete the `sandbox` entry.

## ☐ Step 4 — Delete the Project (optional, if you won't reuse it)
```bash
az devcenter admin project delete --name <your-project-name> --yes
```

## ☐ Step 5 — Delete the Catalog attachment (optional)
This only removes the *link* to your GitHub repo from the Dev Center —
your repo and template files are completely untouched.
```bash
az devcenter admin catalog delete \
  --dev-center-name nexedge-devcenter \
  --name smarthotel-catalog \
  --yes
```

## ☐ Step 6 — Delete the Dev Center itself (optional)
Only do this if you're done with ADE entirely for now. Skip it if you'll
spin up a new environment type/project again soon — the Dev Center itself
costs nothing to leave sitting idle.
```bash
az devcenter admin devcenter delete --name nexedge-devcenter --yes
```

---

### ✅ What survives
- Your GitHub repo (`main.bicep`, `environment.yaml`, `scripts/`) — untouched,
  ready to redeploy any time with `az devcenter dev environment create`
- Nothing billable left running in Azure

### 🔁 Redeploy later
```bash
az devcenter dev environment create \
  --dev-center-name nexedge-devcenter \
  --project-name <your-project-name> \
  --environment-name smarthotel-sim \
  --environment-type sandbox \
  --catalog-name smarthotel-catalog \
  --environment-definition-name SmartHotel-OnPrem-Simulation \
  --user-id me
```
(You'll need the Dev Center/Project/Catalog to still exist for this — if you
deleted them in Steps 4–6, redo Steps 2–4 from the original README first.)
