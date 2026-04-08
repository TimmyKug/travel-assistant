# Load Balancer Migration And Deployment Decisions

## Goal

The goal of this migration was to move the application from a single public VM
to a setup that supports more than one app instance behind a fixed public entry
point. This improves resilience, makes the infrastructure easier to demonstrate
in the presentation, and directly supports the optional bonus area
"erweiterte Load-Balancing-Mechanismen" from the grading criteria.

## Initial Situation

Before the migration, the app used a Managed Instance Group for self-healing,
but effectively still behaved like a single-VM deployment:

- the MIG target size was `1`
- the app VM claimed a reserved regional public IP directly
- GitHub Actions deployed the app by SSHing into one host via Ansible
- the public app address pointed to the VM itself, not to a load balancer

This worked for single-instance recovery, but it was not a clean `N > 1`
architecture.

## Main Problem

The backend itself was already largely ready for horizontal scaling because
state relevant to users was not stored only in process memory:

- authentication uses JWT
- rate limiting and application data are stored in Firestore
- no sticky-session mechanism is required

The real bottleneck was the deployment model:

- the CI/CD pipeline assumed exactly one app IP
- Ansible copied application files to one concrete VM
- with multiple app VMs, that approach would produce drift and mixed versions

## Core Architecture Decision

The key decision was:

- do not keep Ansible as the deployment mechanism for app VMs
- let the app MIG manage app rollouts through the instance template and startup
  script
- keep Ansible only for the monitoring VM

### Why this was the right choice

App instances in a MIG are intentionally replaceable. If one instance fails,
Google Cloud should be able to create a fresh replacement automatically without
requiring a later SSH-based deployment step from GitHub Actions. The startup
script already bootstrapped the app stack on a fresh VM, so it became the
natural deployment path for the app layer.

This gives the architecture a clear separation:

- Terraform defines and updates infrastructure
- the app startup script bootstraps ephemeral app instances
- Ansible configures the persistent monitoring VM

## Implemented Changes

### 1. Public entrypoint moved from VM IP to load balancer

The public application entrypoint is now a global static IP of an external HTTP
load balancer instead of a static IP attached to one VM.

Effects:

- the public IP remains stable across MIG replacements
- app instances can be replaced without changing the public endpoint
- external traffic is directed through the load balancer, not directly to a
  chosen VM

### 2. Managed Instance Group scaled to two app instances

The app MIG was changed from one instance to two instances and configured with
a proactive rolling replace policy.

Effects:

- the setup now actually demonstrates `N > 1`
- one instance can be replaced while another instance stays available
- rollouts happen through instance template changes

### 3. App deployment moved from Ansible to instance-template rollouts

The app deployment flow was changed so that a new image tag updates the app
instance template. This causes the MIG to roll out replacement instances using
the new template.

Effects:

- GitHub Actions no longer needs to SSH into app VMs
- the rollout mechanism matches the infrastructure model
- app instances become self-contained and self-healing

### 4. Image versioning switched to Git SHA-based rollout triggering

The deployment now uses the Git SHA as the app image tag during rollout instead
of relying only on `latest`.

Why this matters:

- `latest` alone does not guarantee a meaningful instance-template change
- with a SHA-based tag, each deploy produces a unique template version
- this reliably triggers the MIG rollout

### 5. App startup script became the authoritative app bootstrap path

The startup script now pulls the deployment files from GCS, ensures the correct
image tag is written into `.env`, authenticates Docker against Artifact
Registry, and starts the application stack.

This makes new or replaced app instances recoverable without manual action.

### 6. Ansible scope was reduced to monitoring only

After the migration succeeded, the old app-side Ansible deployment path was
removed. Legacy files such as the former app role and old redeploy playbook
were deleted so that the repository tells only one deployment story.

Result:

- app deployment: MIG + startup script
- monitoring deployment: Ansible

## CI/CD Changes

The GitHub Actions workflow was adapted in two important ways:

- after infrastructure outputs are resolved and images are built, the rendered
  app config is uploaded to GCS
- then Terraform is applied a second time with the current Git SHA as
  `TF_VAR_app_image_tag`

This means the pipeline now:

1. provisions or updates infrastructure
2. builds and pushes images
3. uploads app bootstrap files to GCS
4. updates the app template to the new image tag
5. lets the MIG roll the application instances
6. still runs Ansible for the monitoring VM only

## Observed Issues And Fixes

### Issue 1: startup script failed because app files were not yet in GCS

During the first rollout, one replacement app VM failed while fetching:

- `docker-compose.yml`
- `promtail.yml`
- `.env`

Root cause:

- the startup script executed before the required object was available in the
  GCS config bucket for that replacement instance

Interpretation:

- this was a rollout timing problem during the migration
- CI/CD itself had completed, but one instance had already started too early

Status:

- the rollout later recovered, but this remains a useful lesson learned
- adding retry logic around the GCS downloads would make the bootstrap more
  robust in the future

### Issue 2: backend container health check failed

The backend container was marked unhealthy because the Docker Compose health
check used `curl`, but the backend image did not contain `curl`.

Fix:

- `curl` was added to the backend Docker image

Result:

- the backend container health check now succeeds
- new app instances can become healthy inside the MIG

### Issue 3: Grafana dashboard was not provisioned automatically

Grafana was configured to load dashboards from `/etc/grafana/dashboards`, but
the compose file only mounted the provisioning directory and not the dashboard
JSON files at that target path.

Fix:

- the dashboards directory was mounted explicitly into the Grafana container

Result:

- the dashboard provisioning works automatically again

## Important Design Decisions And Their Rationale

### Decision: keep startup-script deployment for app VMs

Rationale:

- app VMs in a MIG are disposable by design
- a replacement instance must be able to recover automatically
- requiring Ansible to SSH into each replacement VM would weaken self-healing

### Decision: keep Ansible for monitoring

Rationale:

- the monitoring VM is a single, persistent host
- it owns mounted persistent data for Prometheus, Grafana, and Loki
- this is a good fit for Ansible-style host configuration

### Decision: keep a fixed public IP at the load balancer

Rationale:

- a fixed entrypoint is easier for users, demos, and slides
- the app IP no longer depends on which VM is currently alive
- the public IP now reflects the architecture correctly

### Decision: clean up legacy app Ansible code after success

Rationale:

- keeping two deployment stories in the repository would create confusion
- removing the obsolete app roles makes the architecture easier to explain
- the codebase now reflects the actual operating model

## Final Result

The final architecture after this migration is:

- frontend and backend run on app VMs inside a Managed Instance Group
- the app MIG runs with two instances
- the public app entrypoint is a global static IP of an external HTTP load
  balancer
- health checks and rolling replacements are handled by Google Cloud
- app instances bootstrap themselves via startup script and GCS-provided config
- monitoring remains on a dedicated VM managed with Ansible

## Relevance For The Grading Criteria

This migration strengthens several grading-relevant points:

- Infrastructure deployment through Terraform:
  the load balancer, MIG, startup-based bootstrap path, and static public
  entrypoint are all defined in Terraform.
- Deployment automation:
  GitHub Actions plus Terraform plus Ansible now form a clearer deployment
  chain with separated responsibilities.
- Monitoring:
  Grafana, Prometheus, Loki, and automatic dashboard provisioning remain part
  of the demonstrated platform.
- Focus feature / demonstrable resilience:
  the architecture now supports self-healing and rolling replacement with more
  than one app instance.
- Bonus:
  the project now includes a real load-balancing mechanism instead of just one
  public VM.

## Relevant Commits

- `53525e9` - Add load balancer based app rollout
- `4b3a64a` - fix: update Dockerfile to ensure curl is installed for health
  check
- `9a7e0ca` - fix: add missing volume for Grafana dashboards provisioning
- `5291f62` - Remove legacy app ansible deployment

## Possible Follow-Up Improvement

One useful hardening step remains:

- add retry logic in the app startup script when fetching the deployment files
  from GCS

This is not required for the working architecture, but it would make the app
bootstrap more robust against timing races during replacement and rollout.
