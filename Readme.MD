# On Premises Environment Preparation for Azure Development Environment


##  Step 1 — Push to a repo
ADE reads catalogs from a Git repo. Create a GitHub repo (e.g. `azure-ade-catalog`)
and push this `SmartHotel-OnPrem-Sim/` folder to it (root level, or under a
`/Environments/` folder — either works as long as the catalog path matches).

```
git init
git add .
git commit -m "Stage 1: SmartHotel on-prem simulation template"
git remote add origin <your-repo-url>
git push -u origin main
```

##  Step 2 — Create (or reuse) a Dev Center
Azure Portal → search **"Dev Centers"** → Create.
- Name: `nexedge-devcenter` (or whatever you like)
- Region: same as you'll deploy VMs to

##  Step 3 — Attach this repo as a Catalog
Inside your Dev Center → **Catalogs** → Add.
- Name: `smarthotel-catalog`
- Git clone URI: your repo URL
- Branch: `main`
- Folder path: `/` (or `/Environments` if you nested it)

##  Step 4 — Create an Environment Type + attach a subscription
Dev Center → **Environment types** → Add → name it `sandbox`.
Then on a **Project** (create one if you don't have one) → **Environment types**
→ add `sandbox` and point it at your subscription/resource group.

##  Step 5 — Deploy it
Go to the **Dev Center Developer Portal** (separate URL, not the main Azure
Portal) → New Environment → pick `SmartHotel-OnPrem-Simulation` → fill in
adminUsername / adminPassword / your IP → Create.

Azure spins up the VNet, NSG, and all 4 VMs. Grab the public IPs from the
Outputs tab when it's done.

---

**Cost note:** 4 VMs running 24/7 add up fast. Stop/deallocate them when
you're not actively using the lab — `az vm deallocate` per VM, or just
delete the whole environment from the Developer Portal when a session's done
(ADE makes teardown one click, which is the whole point).

**Stage 2 is now built in.** The same `environment.yaml` deploys it — set
`catalogRawBaseUrl` to your repo's raw scripts path (see Step 1 below) and
`sqlAppPassword` to a strong password, and `deployApps` (on by default) does
the rest:

- **SmartHotelSQL1** → creates `SmartHotelDB` with a `Rooms` table + sample data
- **SmartHotelWeb1 / Web2** → IIS + a live ASP.NET page that queries SQL and
  shows which server answered the request
- **UbuntuWAF** → Nginx reverse proxy load-balancing across both web VMs,
  with basic bot/SQLi-pattern blocking rules

When deployment finishes, hit the `appUrl` output in your browser — refresh
a few times and watch it bounce between Web1 and Web2.

**Important:** the extensions pull scripts from `catalogRawBaseUrl`, so
Step 1 (pushing to GitHub) must happen *before* you deploy, and the repo
needs to be public (or use a SAS-protected fileUri if private).
