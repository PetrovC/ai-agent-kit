# Infrastructure Skill — Deep Reference

> Loaded on demand. The slim [`SKILL.md`](SKILL.md) covers the quick reference.

## Universal principles

- **Everything in version control.** Cloud console actions are for inspection, not change.
- **Immutable artifacts.** Build once, promote the same artifact through environments.
- **Least privilege.** Every secret and every IAM role does one thing.
- **Fail loud.** Health checks, alerts, log aggregation from day one.
- **Cost visibility.** Tag every resource with `owner`, `env`, `cost-center`.

---

## Docker

### Dockerfile

- Use **multi-stage builds** for compiled languages. Final image must not contain build tools.
- Pin base image versions: `node:20.11.1-alpine`, not `node:latest`. Better: digest pinning (`node@sha256:...`).
- Run as a non-root user. Add a `USER appuser` near the end.
- One process per container. No SSH, no cron.
- Order layers by change frequency: dependencies first, code last → cache hit rate.
- `.dockerignore` is mandatory — exclude `node_modules`, `.git`, `dist`, secrets.

```dockerfile
# syntax=docker/dockerfile:1.7

FROM node:20.11.1-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile --prod

FROM node:20.11.1-alpine AS runner
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --chown=app:app . .
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

### docker-compose

- For local dev only. Don't run production with compose unless it's a tiny single-host deployment with an explicit decision.
- Use named volumes, not bind mounts, for stateful services.
- Pin `image:` versions. Never `:latest`.

---

## Kubernetes

- **Manifests in repo**: `k8s/` folder OR Helm chart OR Kustomize. Pick one approach.
- One `Deployment` per service. `Service` for in-cluster networking. `Ingress` for external.
- **Resource requests + limits on every container.** Without them, the scheduler can't pack pods and OOM kills are unpredictable.
- **Liveness vs readiness**: readiness gates traffic, liveness restarts the pod. Don't confuse them.
- **ConfigMap** for non-secret config. **Secret** for credentials (and use external-secrets / sealed-secrets — don't commit base64).
- Don't use `:latest` tags. Use immutable digests or versioned tags.
- `terminationGracePeriodSeconds` matched to the app's shutdown hook.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels: { app: api, env: prod }
spec:
  replicas: 3
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
        - name: api
          image: ghcr.io/org/api@sha256:abc...
          ports: [{ containerPort: 8080 }]
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { cpu: 500m, memory: 512Mi }
          readinessProbe:
            httpGet: { path: /health/ready, port: 8080 }
            initialDelaySeconds: 5
          livenessProbe:
            httpGet: { path: /health/live, port: 8080 }
            initialDelaySeconds: 30
```

### Helm / Kustomize

- **Helm** when you publish a reusable chart or use upstream charts.
- **Kustomize** when overlays per environment are the only variation. Simpler than Helm for in-house apps.
- Don't template YAML with bash. That way lies madness.

---

## Terraform / OpenTofu

- One folder per environment (`envs/prod`, `envs/staging`), shared modules under `modules/`.
- **Remote state**, with **state locking** (S3 + DynamoDB, GCS, Terraform Cloud, etc.).
- `terraform fmt -recursive` + `terraform validate` in CI.
- **`terraform plan` in PR, `terraform apply` only on merge to main** (or manual approval gate).
- Pin provider versions in `required_providers`.
- Pin module versions when sourcing from a registry (`source = "..."`, `version = "x.y.z"`).
- Never store secrets in state — use a secret manager and read via data source.
- Tag every resource: `tags = { owner = "team-a", env = var.env, project = "myapp" }`.

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.40" }
  }
  backend "s3" {
    bucket         = "myorg-tfstate"
    key            = "prod/api/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "tfstate-locks"
    encrypt        = true
  }
}
```

---

## CI/CD

### Common rules across runners

- **One workflow per concern**: build, test, deploy, security scan. Don't stuff everything in one job.
- **Cache dependencies** by lockfile hash.
- **Smallest possible permissions**: GitHub Actions `permissions:` block, GitLab `id_tokens:`, etc.
- **No secrets in logs**. Use masked secrets, never `echo $SECRET`.
- **Build artifacts once**, promote across environments. Don't rebuild for staging vs prod.
- **Pin actions / images** to commit SHAs, not `@v1` (which can move).

### GitHub Actions example

```yaml
name: build-and-test
on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11   # v4.1.1
      - uses: pnpm/action-setup@v3
        with: { version: 8 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm tsc --noEmit
      - run: pnpm test --coverage
```

---

## Secrets

- Never in repo, never in CI logs, never in Slack.
- Use the provider's secret manager (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, HashiCorp Vault).
- Rotate on a schedule. Document the rotation runbook.
- For local dev: `.env` ignored by git; `.env.example` committed with placeholder values.

---

## Observability

- **Logs**: structured JSON to stdout. Let the platform collect (Cloudwatch, Loki, Datadog).
- **Metrics**: Prometheus / OpenTelemetry. Histograms for latency, counters for errors, gauges for in-flight requests.
- **Traces**: OpenTelemetry. Propagate context across services.
- Alerts on SLO breaches (latency p99, error rate), not on individual errors.

---

## What NOT to do

- No `:latest` tags in production manifests.
- No `chmod 777` or `chown -R` in Dockerfiles "to make it work."
- No `terraform apply` without a fresh `plan`.
- No SSH-ing into prod to change config. Change the manifest, redeploy.
- No secrets in environment variables of public-facing services without rotation.
- No `--privileged` containers without a documented reason and isolation.
- No untagged cloud resources — debugging cost spikes later is impossible.

---

## Verification commands

```bash
# Docker
docker build -t myapp:test .
hadolint Dockerfile                    # lint
trivy image myapp:test                 # CVE scan

# Kubernetes
kubectl apply --dry-run=server -f k8s/
kubeconform -strict k8s/
kube-score score k8s/

# Terraform
terraform fmt -recursive -check
terraform validate
terraform plan -out=plan.tfplan
tflint
tfsec . || trivy config .

# CI
actionlint .github/workflows/*.yml
```

---

## Final response requirements

Always report:
- Files changed (Dockerfile / k8s manifest / Terraform module / CI workflow).
- Security implications: new permissions, network rules, exposed ports.
- Cost implications: new instances, storage, egress.
- Rollback plan: how to revert if this breaks production.
- Any new dependency or provider: name, version, **license (MIT only — see `dependencies` skill)**.
