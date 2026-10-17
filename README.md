# blue-green-edge-deploy

This repository is a small status page used to demonstrate a blue-green deployment on AWS. The page is deliberately generic: Northwind Widgets has four services (api, web, payments, and search) and synthetic incidents. The useful part of the example is the delivery path, not the sample content.

## The pattern

Two complete copies of the site live behind one CloudFront distribution. Every deployment is uploaded to the inactive color. A local or CI smoke test checks that copy before the active color alias is changed. CloudFront Functions read the `active_color` value from a CloudFront KeyValueStore and rewrite `/` and asset paths to either `/blue/...` or `/green/...`. Rollback is the inverse operation: find a recorded version, restore it to its color prefix, and point the alias back to that color.

```mermaid
flowchart LR
  User[Browser] --> CF[CloudFront]
  CF --> Router[CloudFront Function<br/>KVS active_color]
  Router --> S3[(Private versioned S3 bucket)]
  CF --> Auth[Lambda@Edge viewer-request]
  Auth --> Cognito[Cognito user pool<br/>admins group]
  S3 --> Blue[blue/ prefix]
  S3 --> Green[green/ prefix]
  Deploy[GitHub Actions OIDC] --> Role[IAM deploy role]
  Role --> S3
  Role --> KVS[(CloudFront KVS)]
```

The S3 bucket is private and is reachable only through a CloudFront Origin Access Control. `infra/` provisions the bucket, distribution, KVS, router function, Lambda@Edge package, Cognito resources, and a GitHub Actions OIDC deploy role. The example deliberately leaves the domain and account-specific values to `terraform.tfvars`.

## Deploy and rollback sequence

1. `scripts/seed.py` writes deterministic status data using a fixed random seed.
2. `scripts/build.py` hashes the source files and creates `dist/<timestamp>-<hash>/`, including a build manifest.
3. `scripts/deploy.sh` selects the inactive color, copies the immutable artifact into its color prefix and archive, and runs `scripts/smoke_test.py`.
4. Only after smoke testing, the active color alias is flipped. The version and color are appended to `deployments/manifest.json`.
5. `scripts/rollback.sh <version>` restores the recorded artifact and repoints the alias. `scripts/rollback_drill.sh` measures the local operation.

In AWS mode the same sequence is intended to map to `aws s3 sync`, a CloudFront KeyValueStore update, and a CloudFront invalidation where needed. The scripts' offline path is complete and is the testable reference implementation.

## Run locally

No AWS credentials are needed. From the repository root, run:

```text
make deploy-local
```

This creates `data/status.json`, an immutable `dist/<version>/` artifact, a simulated S3 tree in `.local_s3/`, an alias in `.local_state/active_color`, and `deployments/manifest.json`. The local page is at `.local_s3/<active-color>/app/index.html`. To serve it in a browser after the deployment, use `python3 -m http.server --directory .local_s3/<active-color> 8000`; the page's absolute asset paths are the same paths CloudFront rewrites in the real distribution.

Useful commands:

```text
make seed
make build
make test
make rollback-local VERSION=<version-from-deployments-manifest>
make drill
make tf-validate
```

`DRY_RUN=1` and `--local` select the offline deploy/rollback implementation. The AWS path intentionally requires explicit environment configuration and credentials rather than guessing a bucket or distribution.

## Admin auth matrix

The Lambda@Edge viewer-request gate runs before the origin request. Config-like files are hidden even from admins.

| Request | Result |
|---|---:|
| Public path without a token | 200 |
| `/admin*` without a token | 401 |
| `/admin*` with a valid token but no `admins` Cognito group | 403 |
| `/admin*` with a valid token in `admins` | 200 |
| Any `*.config.json` request | 404 |
| Any `/admin/config*` request | 404 |

The edge module accepts an injected verifier. That keeps JWT signature verification separate from the routing decision and makes the matrix testable without shipping a crypto dependency into this MVP. A production verifier must validate the Cognito issuer, audience, expiry, and signature against the user pool's rotating JWKS.

## Tradeoffs

- Blue-green makes a full rollback simple and gives a deployment a clean pre-promotion smoke-test target. It costs roughly two copies of the static artifact and does not provide the gradual exposure of a canary.
- A canary can discover behavior under a small percentage of real traffic, but it needs weighted routing, measurement, and a more involved rollback policy. Blue-green is easier to reason about for this status page.
- Immutable paths reduce accidental overwrites, but browser and CloudFront caches still need a policy. Hashed assets can use long TTLs; `status.json` should use a short TTL or an invalidation when data changes.
- Lambda@Edge functions replicate to edge locations. A code change can take time to appear everywhere, so auth changes are not an instantaneous global switch.
- CloudFront KeyValueStore updates also have propagation delay. The alias flip is fast but not necessarily simultaneous at every edge location.
- CloudFront, S3, Cognito, Lambda@Edge replication, and KVS add cost and operational surface compared with hosting a single static directory.

## What I would do in production

I would use a real remote Terraform state backend with locking, replace the placeholder GitHub repository constraint with the exact repository and protected deployment environment, and pin provider and action versions. I would verify Cognito JWTs with a tested JWKS cache, add structured edge logging and alarms for 401/403/5xx responses, and make the deployment record durable in a control-plane store rather than a workspace file. I would add an explicit approval gate before promotion, separate content data from the application artifact, publish cache-control headers, test the distribution from several regions, and regularly run an automated rollback drill. Secrets and user creation would remain outside the repository.

## Checks

CI runs Python pytest tests, Node 20 tests, Terraform formatting and validation without applying infrastructure, gitleaks, and the deny-list scan. The deploy workflow is `workflow_dispatch` only and uses GitHub Actions OIDC; it has no automatic trigger.
