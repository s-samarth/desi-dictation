# Deploying the web demo — laptop → your domain → AWS

Three stages, each one strictly optional until you outgrow the previous.
Written 2026-07-14 for someone who has never used AWS. The app-side pipeline
(DMG releases) is in [CICD.md](CICD.md); this is the web demo only.

## Why not Vercel (read this first)

Vercel runs short-lived serverless functions. This demo needs the opposite:
**resident processes** — whisper-server keeps a ~600 MB model in memory,
Ollama keeps a ~3 GB LLM in memory (GPU-accelerated), ffmpeg runs per
request. Serverless would reload gigabytes per invocation, has no GPU, and
caps execution time/body size below a 60 s audio clip. Vercel is fine later
for a static landing page that *links* to the demo; the demo itself needs a
real machine. Your laptop is that machine today; an EC2 GPU box is it later.

## Stage 1 — laptop, localhost (works today)

```bash
./web/setup_demo.sh    # one-time
./web/run_demo.sh      # → http://localhost:8080
```

## Stage 2 — laptop, public link on YOUR domain ($0)

Browsers require **HTTPS** for mic access, so `http://<your-ip>` can never
work for visitors. Cloudflare Tunnel solves HTTPS + port-forwarding + your
domain in one free move, with no server:

1. Add your domain to Cloudflare (free plan) — at your registrar, switch the
   domain's nameservers to the two Cloudflare gives you.
2. On the laptop:
   ```bash
   brew install cloudflared
   cloudflared tunnel login                 # browser opens, pick the domain
   cloudflared tunnel create desi-demo
   cloudflared tunnel route dns desi-demo demo.yourdomain.com
   cloudflared tunnel run --url http://localhost:8080 desi-demo
   ```
3. `https://demo.yourdomain.com` now serves the demo — stable URL, real HTTPS,
   as long as `run_demo.sh` + the tunnel are running and the lid is open
   (`caffeinate -s` prevents sleep).

No account/domain yet? `cloudflared tunnel --url http://localhost:8080`
prints a throwaway `https://<random>.trycloudflare.com` link instantly.

**This stage covers launch week.** An M3 transcribes at 3–15× realtime; only
sustained concurrent traffic (LLM requests serialize) forces Stage 3.

## Stage 3 — AWS EC2 (24/7 uptime, real traffic)

### What to rent

**g4dn.xlarge** (4 vCPU, 16 GB RAM, NVIDIA T4 16 GB) in **ap-south-1
(Mumbai)** — closest region to Indian visitors. The T4 runs both whisper.cpp
(CUDA) and Ollama fast; CPU-only alternatives make the AI actions take
10–20 s (full comparison table: [web/README.md](../web/README.md)).
~$385/month on-demand — but see cost control below; you should pay a
fraction of that.

### First-time AWS setup, in order

1. **Account**: aws.amazon.com → Create account (needs a card). Then in the
   console: IAM → enable **MFA** on the root user (do this before anything).
2. **Billing alarm**: Billing → Budgets → create a monthly budget (say $50)
   with an email alert. This is your "something is silently running" tripwire.
3. **Region**: top-right dropdown → **Asia Pacific (Mumbai) ap-south-1**.
   Everything below happens inside this region.
4. **GPU quota** (the newbie trap): new accounts are allowed **zero** GPU
   instances. Console → Service Quotas → EC2 → "Running On-Demand G and VT
   instances" → request increase to **4 vCPUs**. Usually approved in hours.
5. **Key pair**: EC2 → Key Pairs → Create (type ED25519, .pem) → it downloads
   once; `chmod 400 ~/Downloads/desi.pem` and keep it safe. This is your SSH
   login — there are no passwords.
6. **Launch instance**: EC2 → Launch instance →
   - AMI: **Ubuntu Server 24.04 LTS (64-bit x86)**
   - Type: **g4dn.xlarge** · Key pair: the one above
   - Network: allow SSH **from "My IP" only**; allow HTTP (80) + HTTPS (443)
     from anywhere. **Never** open 8080/8081/8082/11434 to the world — Caddy
     is the only public door.
   - Storage: **100 GB gp3** (models + CUDA toolchain are big).
7. **Elastic IP** (a static address that survives restarts): EC2 → Elastic
   IPs → Allocate → Associate with the instance.
8. **DNS**: in Cloudflare (or your registrar), add an **A record**:
   `demo.yourdomain.com → <Elastic IP>`.
9. **SSH in**: `ssh -i ~/Downloads/desi.pem ubuntu@<Elastic IP>`

### On the server (once)

Follow web/README.md "Moving to AWS" §1–4 (deps, Ollama, whisper.cpp with
`-DGGML_CUDA=1`, scp the models + `web/` from the Mac). Then:

```bash
# HTTPS: Caddy fetches + renews certificates automatically
sudo apt install -y caddy
echo 'demo.yourdomain.com { reverse_proxy :8080 }' | sudo tee /etc/caddy/Caddyfile
sudo systemctl reload caddy

# keep everything alive across reboots
sudo systemctl enable --now ollama
sudo tee /etc/systemd/system/desi-web.service >/dev/null <<'EOF'
[Unit]
Description=Desi Dictation web demo
After=network.target ollama.service
[Service]
User=ubuntu
ExecStart=/home/ubuntu/desi-dictation/web/run_demo.sh
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now desi-web
```

Open `https://demo.yourdomain.com` — done.

### Every change after that

```bash
./scripts/deploy_web.sh ubuntu@<Elastic IP>     # from the Mac; or:
```
set repo variable `DEPLOY_ENABLED=true` + secrets `DEPLOY_HOST`/`DEPLOY_KEY`
(the .pem contents) on GitHub and **every green push to main deploys
itself** — the pipeline is already wired ([CICD.md](CICD.md)).

### Cost control (important)

- A stopped instance costs ~nothing (just the disk, ~$8/mo). Stop it whenever
  the demo isn't being shown: `aws ec2 stop-instances --instance-ids i-…`
  (or the console button). The Elastic IP + DNS keep working on restart.
- **Spot** pricing cuts g4dn.xlarge to ~$115/mo (can be reclaimed with 2 min
  warning — fine for a demo, wrong for production).
- Don't leave a $385/mo box idling for visitors who aren't there. Laptop +
  tunnel (Stage 2) is genuinely enough until traffic proves otherwise.
- Real production (autoscaling, serverless GPU, quotas) is a different design
  and already written up in [cloud/](cloud/README.md) — don't build it early.
