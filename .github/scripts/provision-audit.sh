#!/usr/bin/env bash
# Best-effort audit provisioning for the agent CI workflows.
#
# Writes the SSH deploy key + global audit config so the kit's emit-event /
# finalize-run can push an anonymized run to the private audit repo. Fail-open:
# when AAK_AUDIT_DEPLOY_KEY is absent it skips and exits 0, so the agent step is
# never blocked. GitHub forbids the `secrets` context in `if:`, so the key is
# read from the environment and gated here in the script instead.
set -euo pipefail

if [ -z "${AAK_AUDIT_DEPLOY_KEY:-}" ]; then
    echo "AAK_AUDIT_DEPLOY_KEY not set — skipping audit provisioning."
    exit 0
fi

mkdir -p ~/.ssh ~/.ai-agent-kit
printf '%s\n' "$AAK_AUDIT_DEPLOY_KEY" > ~/.ssh/aak_audit_deploy
chmod 600 ~/.ssh/aak_audit_deploy
cat >> ~/.ssh/config <<'SSH'
Host github-aak-audit
    HostName github.com
    User git
    IdentityFile ~/.ssh/aak_audit_deploy
    IdentitiesOnly yes
SSH
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true

# finalize-run commits into the freshly-cloned central audit repo, which has no
# author identity in CI; set a global one so the commit (and therefore the push)
# succeeds. Only configured when audit is actually provisioned.
git config --global user.name "github-actions[bot]"
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

cat > ~/.ai-agent-kit/config.json <<'CFG'
{
  "schema_version": "0.1.0",
  "audit": {
    "enabled": true,
    "mode": "official-central-repo",
    "official_remote_url": "git@github-aak-audit:PetrovC/ai-agent-kit-audit.git",
    "branch": "agent-audit-data",
    "runtime_path": "~/.ai-agent-kit/audit-runtime",
    "central_repo_path": "~/.ai-agent-kit/central-audit",
    "source_project_write_policy": "never",
    "push": { "mode": "authorized", "commit": true, "unauthorized_fallback": "local-outbox" }
  }
}
CFG
echo "Audit provisioning complete."
