# TaskFlow --- Complete AWS Three-Tier DevOps Project Documentation

This document is a handover guide for an engineer who needs to
understand, reproduce, operate, or extend the TaskFlow project. It
explains the architecture, the purpose of each AWS service, the request
flow, the deployment process, validation, known limitations, and the
evidence/screenshots that should accompany the repository.

> \*\*Accuracy note:\*\* This guide describes the implementation and status
> recorded for this project. Resource IDs, account IDs, secrets, and
> environment-specific values are intentionally represented as
> placeholders. Verify the live AWS console and Terraform state before
> using this as an operational runbook.

## 1\. Project objective

Build and deploy a three-tier web application on AWS while demonstrating
practical DevOps engineering:

* Infrastructure as Code using Terraform.
* Network isolation using a VPC and public/private subnets.
* A public application entry point using an Application Load Balancer.
* Private application compute on EC2.
* A private PostgreSQL database on Amazon RDS.
* Frontend hosting on private S3, delivered through CloudFront.
* Secure GitHub Actions authentication to AWS using OIDC.
* CI/CD validation, deployment, health checks, and rollback handling.
* Private instance administration using AWS Systems Manager.
* Monitoring using CloudWatch.

The goal is not merely to launch an application. The project
demonstrates how the infrastructure, security boundaries, deployment
pipeline, and application work together.

## 2\. High-level architecture

``` text
                         Browser / User
                               |
                               v
                        CloudFront CDN
                         /           \\
            Default behavior         /api/\* behavior
                    |                      |
                    v                      v
             Private S3 bucket       Application Load Balancer
             (frontend files)                |
                    ^                        v
                    |                 Private EC2 instance
             CloudFront OAC            TaskFlow backend
                                             |
                                             v
                                      Private RDS PostgreSQL
```

### Request flow

**Frontend request**

1. A user opens the CloudFront domain.
2. CloudFront checks its cache for the requested frontend object.
3. If the object is cached and still valid, CloudFront can serve it
from the edge cache.
4. If it is not cached or needs revalidation, CloudFront retrieves it
from the private S3 origin.
5. CloudFront uses Origin Access Control (OAC) to sign requests to S3.
The bucket policy permits the intended CloudFront distribution to
read the objects.
6. The browser receives the frontend HTML, JavaScript, CSS, and other
static assets.

**API request**

1. The frontend sends a request to a path beginning with `/api/`.
2. CloudFront selects the `/api/\*` cache behavior.
3. That behavior forwards the request to the Application Load Balancer
origin.
4. The ALB forwards the request to a healthy registered backend target.
5. The private EC2 instance runs the TaskFlow backend service.
6. The backend connects to the private PostgreSQL database.
7. The response travels back through the ALB and CloudFront to the
browser.

## 3\. AWS region and resource layout

The project was built in AWS region `ap-south-1` (Mumbai).

The VPC CIDR used is `10.0.0.0/16`.

The subnet plan recorded for the project is:

\---

Subnet purpose    CIDR              Availability Zone Role

\---

Public subnet     `10.0.1.0/24`     `ap-south-1a`     ALB entry point

Private           `10.0.11.0/24`    `ap-south-1a`     Backend EC2
application  
subnet

Private database  `10.0.21.0/24`    `ap-south-1b`     RDS subnet
subnet                                                placement
---

Verify the actual subnet IDs and AZ assignments in the AWS account and
Terraform state before recreating the environment.

### Understanding the CIDR ranges

* IPv4 addresses contain 32 bits, split into four 8-bit octets.
* `/16` means the first 16 bits are the network portion. For
`10.0.0.0/16`, the first two octets (`10.0`) are fixed.
* The remaining 16 bits can vary, so the address range is `10.0.0.0`
through `10.0.255.255`.
* `/24` fixes the first 24 bits. The last octet can vary from 0 to
255.
* A `/24` contains 256 total addresses. AWS reserves five addresses in
each IPv4 subnet, leaving 251 usable addresses.

The subnets must be contained inside the VPC CIDR and must not overlap.

## 4\. VPC and networking

### VPC

The VPC is the isolated network boundary for the application resources.
It defines the private IP address range and contains the subnets, route
tables, security groups, and VPC endpoints.

### Public subnet

The public subnet contains the ALB. Its route table has a route to the
Internet Gateway for internet-facing traffic. The backend EC2 and RDS
database are not placed in this public subnet.

### Private application subnet

The backend EC2 instance is placed in the private application subnet. It
does not need a public IP for the intended architecture. Incoming
application traffic should reach it through the ALB, and administrative
access should use Systems Manager rather than opening SSH to the
internet.

### Private database subnet

RDS is placed in private database subnet infrastructure. The database
should not be publicly accessible. Its security group should accept the
PostgreSQL port only from the backend EC2 security group (or another
explicitly authorized application security group).

### Internet Gateway

An Internet Gateway provides internet connectivity for resources in
subnets whose route tables direct traffic to it. It is associated with
the VPC. A route to the Internet Gateway does not automatically make
every resource public; public addressing and security rules also matter.

### Route tables

A route table determines where subnet traffic is sent.

* Public route table: includes the VPC-local route and a default route
(`0.0.0.0/0`) to the Internet Gateway.
* Private application/database route tables: include the VPC-local
route and any required service-specific endpoint routes. The project
intentionally avoids a NAT Gateway to reduce ongoing costs.

Always inspect the actual route table associations. A subnet is not
public merely because it has a name containing "public"; its route table
and addressing configuration determine its network behavior.

### Security groups

Security groups are stateful virtual firewalls attached to AWS
resources. Use least-privilege rules.

Expected traffic design:

\---

Resource          Inbound source    Port/protocol     Purpose

\---

ALB               Approved client   HTTP/HTTPS as     Public
internet traffic  configured        application entry

Backend EC2       ALB security      Application       Accept
group             listener port     application
requests only
from ALB

RDS PostgreSQL    Backend EC2       TCP 5432          Database
security group                      connections

VPC interface     Backend EC2       TCP 443           Private HTTPS
endpoints         security group                      access to
endpoint services
---

Do not copy these as exact rules without checking the application port,
TLS configuration, and current security groups. Avoid broad rules such
as `0.0.0.0/0` for SSH or PostgreSQL.

## 5\. VPC endpoints and private AWS service access

The backend instance is private and the project does not use a NAT
Gateway. VPC endpoints provide private connectivity to selected AWS
services.

Endpoints recorded for this project:

* `com.amazonaws.ap-south-1.ssm` --- Systems Manager API.
* `com.amazonaws.ap-south-1.ssmmessages` --- Systems Manager messaging
channel.
* `com.amazonaws.ap-south-1.s3` --- S3 gateway endpoint.

### Why these endpoints matter

Without a NAT Gateway or another egress path, a private instance cannot
generally reach public AWS service endpoints over the internet. The SSM
interface endpoints allow the SSM agent to communicate with Systems
Manager privately. The S3 gateway endpoint provides private routing to
S3 for supported traffic.

A VPC endpoint is not general internet access. It only provides access
to the configured AWS service (and, depending on endpoint policy and
routing, permitted resources).

### Systems Manager access

The EC2 instance role includes `AmazonSSMManagedInstanceCore`. The
instance must also have a working SSM Agent and network access to the
required Systems Manager endpoints.

Use Session Manager or Run Command for administration and deployment. Do
not expose SSH simply to make administration easier.

## 6\. Backend compute

The backend runs on an Ubuntu 24.04 EC2 instance in the private
application subnet.

Recorded configuration:

* Instance type: `t3.micro`.
* Operating system: Ubuntu 24.04.
* Private IP recorded during implementation: `10.0.11.184`.
* systemd service: `taskflow-backend.service`.

The private IP and instance type are historical project details; confirm
current values in EC2 before operating the server.

### Check the service

Run these commands on the EC2 instance through SSM Session Manager:

``` bash
sudo systemctl status taskflow-backend.service
sudo journalctl -u taskflow-backend.service -n 100 --no-pager
```

To follow logs:

``` bash
sudo journalctl -u taskflow-backend.service -f
```

To restart the backend, only after confirming the reason and deployment
state:

``` bash
sudo systemctl restart taskflow-backend.service
```

Do not print or share the backend `.env` file. It contains sensitive
configuration. Do not include its contents in screenshots, Git commits,
issue reports, or this documentation.

## 7\. Database tier

The database is Amazon RDS for PostgreSQL and is intended to remain
private.

Security principles:

* Public accessibility should be disabled.
* The RDS security group should allow TCP 5432 only from the backend
security group.
* Database credentials must be stored securely and not committed to
Git.
* Use backups and retention settings appropriate to the required
recovery objective.
* Test restoration separately; the existence of automated backups
alone does not prove that recovery works.

The exact RDS engine version, instance class, storage size, backup
retention, and database name should be checked in the live AWS account
and recorded in a private operations inventory, not guessed from this
guide.

## 8\. Frontend hosting: S3 and CloudFront

### Frontend S3 bucket

The frontend build output is stored in a private S3 bucket. The recorded
bucket naming pattern is:

`taskflow-frontend-<account-id>-<region>`

The actual bucket used during implementation was named using the AWS
account and region. Keep the bucket private and enable S3 Block Public
Access.

### Deployment bucket

A separate deployment-related S3 bucket was created using the naming
pattern:

`taskflow-deploy-<account-id>-<region>`

Keep its purpose and lifecycle rules clear. Do not assume it is the
frontend origin bucket.

### CloudFront

CloudFront is the CDN and public delivery layer. It can cache frontend
files at edge locations closer to users.

The distribution has two important origin paths:

* Default behavior: frontend S3 origin.
* `/api/\*` behavior: ALB origin.

Verify the actual origin names, behavior order, allowed HTTP methods,
cache policies, origin request policies, and TLS settings in the
CloudFront console.

### Origin Access Control (OAC)

OAC allows CloudFront to access a private S3 origin using signed
requests. The S3 bucket policy grants read access to the intended
CloudFront distribution. This avoids making the S3 bucket public.

OAC protects the S3 origin; it does not replace application
authorization or API security.

### Cache updates after a deployment

If an object is cached at an edge location, changing the object in S3
does not necessarily make every edge immediately serve the new version.
The old cached object can remain until its TTL expires or it is
invalidated.

The deployment pipeline refreshes CloudFront content after uploading the
frontend build. The recorded distribution ID is environment-specific and
should not be copied into public documentation unless intentionally
disclosed.

A broad invalidation such as `/\*` refreshes all matching paths, but
repeated broad invalidations may incur charges beyond any free
allowance. Prefer content-hashed asset filenames and targeted
invalidations where the build and cache policy support them.

## 9\. CI/CD with GitHub Actions

The project uses GitHub Actions to validate and deploy application
changes.

Workflow file recorded in the repository:

``` text
.github/workflows/deploy.yml
```

### Pull request validation

The workflow includes validation such as:

* Backend integration tests using an isolated PostgreSQL 16 test
service.
* Frontend linting and build checks.
* Node test runner/test cases.
* TAP test report artifact output.

Pull requests are intended to run validation only and must not deploy to
the production AWS environment.

### Production deployment guard

The deployment path is guarded so that production deployment runs only
for the intended non-pull-request `main` branch workflow. The GitHub
production environment is restricted to the `main` branch.

Review the current workflow YAML before changing branch conditions or
deployment permissions.

### GitHub OIDC authentication to AWS

The workflow uses GitHub OIDC rather than storing long-lived AWS access
keys as GitHub secrets.

The authentication sequence is:

1. GitHub Actions requests an OIDC identity token.
2. AWS STS receives the token through `AssumeRoleWithWebIdentity`.
3. AWS validates the token against the IAM role trust policy, including
repository/branch/environment conditions.
4. AWS returns temporary credentials for the role session.
5. The workflow uses those temporary credentials to perform only the
AWS actions allowed by the role's permissions policy.

OIDC is the identity/authentication mechanism. IAM role permissions
determine authorization.

The deployment role recorded for the project is named
`TaskFlowGitHubActionsRole`. Its trust policy and permissions should be
reviewed periodically. Keep permissions as narrow as possible.

### Frontend deployment

The workflow builds the frontend, uploads the generated build output to
the frontend S3 bucket, and refreshes CloudFront content as configured
by the workflow.

### Backend deployment

The workflow uses AWS Systems Manager Run Command to deploy to the
private EC2 instance. This avoids requiring a public SSH endpoint.

The deployment process includes health checks and rollback handling. The
exact script commands and rollback criteria are defined in the current
workflow/repository scripts; inspect those files before modifying the
deployment process.

### Deployment verification

After a successful workflow run:

1. Confirm the GitHub Actions job completed successfully.
2. Confirm the SSM Run Command succeeded for the intended instance.
3. Check the backend service status and logs.
4. Check the ALB target group health.
5. Open the CloudFront application URL.
6. Test the frontend and API behavior.
7. Verify CRUD operations if the change affects application data.

## 10\. Testing and validation

The project has recorded successful frontend CRUD testing and a passing
GitHub Actions run after merging the initial CI/CD workflow pull
request.

Use this validation checklist after a deployment:

### Infrastructure

* \[ ] VPC and expected subnets exist.
* \[ ] Subnet route table associations are correct.
* \[ ] ALB is internet-facing only if that is the intended design.
* \[ ] Backend EC2 has no unintended public exposure.
* \[ ] RDS is not publicly accessible.
* \[ ] Security group references follow least privilege.
* \[ ] SSM managed-node status is online.

### Application

* \[ ] CloudFront domain loads the frontend.
* \[ ] Frontend assets load without unexpected 403/404 responses.
* \[ ] `/api/\*` requests reach the ALB origin.
* \[ ] ALB target group reports the backend target healthy.
* \[ ] Backend service is active.
* \[ ] Backend can connect to PostgreSQL.
* \[ ] Create, read, update, and delete operations work as expected.

### CI/CD

* \[ ] Pull request validation passes.
* \[ ] Pull request does not deploy to AWS.
* \[ ] Main-branch deployment uses OIDC.
* \[ ] Frontend upload completes.
* \[ ] Backend SSM command completes.
* \[ ] Health checks pass.
* \[ ] Rollback path is reviewed and tested safely.

metrics are visible in CloudWatch.

## 11\. Cost-conscious design choices

The project intentionally avoids a NAT Gateway. NAT Gateways have
ongoing hourly and data-processing charges. Instead, selected private
AWS service access is provided through VPC endpoints.

This reduces one category of cost but also means the private EC2
instance does not have general internet egress. Any software
installation or external API access from that instance needs an
explicitly designed network path.

Other cost controls:

* Use small instance sizes appropriate for a learning environment.
* Monitor RDS, ALB, CloudFront, S3, and VPC endpoint charges.
* Avoid unnecessary CloudFront invalidations.
* Remove unused resources after the project is no longer needed.
* Keep a budget alert and review AWS Billing regularly.

Always check current AWS pricing for the selected region and services.

## 13\. Reproducing or handing over the project

A new engineer should follow this order:

1. Read the root `README.md` and this document.
2. Inspect the Terraform directory and identify its providers,
variables, outputs, and state backend configuration.
3. Confirm the target AWS account and region.
4. Review Terraform plan before applying any infrastructure changes.
5. Confirm VPC, subnet, route table, endpoint, and security group
design.
6. Confirm the ALB, target group, EC2 instance, and RDS configuration.
7. Confirm the S3 bucket privacy and CloudFront OAC/bucket policy.
8. Review the GitHub Actions workflow and IAM OIDC trust policy.
9. Configure GitHub repository/environment settings required by the
workflow.
10. Deploy only after reviewing the plan, workflow conditions, and
target environment.
11. Run the validation checklist in Section 10.
12. Record any deviations from the architecture in this document.

### Important Terraform precautions

* Never commit `.tfstate`, `.tfstate.backup`, plan files containing
secrets, `.env` files, private keys, or credentials.
* Check `.gitignore` and Terraform backend configuration.
* Run `terraform fmt` and `terraform validate`.
* Review `terraform plan` before `terraform apply`.
* Do not run `terraform destroy` against a shared or active
environment without explicit authorization and a verified
backup/recovery plan.
* Protect the Terraform state. State can contain sensitive values even
when outputs are marked sensitive.

This guide intentionally does not invent exact Terraform commands,
module names, variable names, or resource addresses. Use the
repository's actual Terraform configuration and README variables as the
source of truth.

## 14\. Troubleshooting guide

### CloudFront returns an old frontend version

Possible causes: - Edge cache still contains an older object. - The
frontend build did not upload to the expected bucket. - The wrong
distribution or origin was updated. - The invalidation has not
completed.

Checks: 1. Confirm the new build exists in the S3 origin bucket. 2.
Confirm CloudFront points to that bucket. 3. Check the relevant cache
behavior and TTL. 4. Check invalidation status. 5. Prefer versioned
asset names and invalidate only the required paths when practical.

### API requests fail

Check in this order: 1. Browser network request and response status. 2.
CloudFront `/api/\*` behavior and ALB origin. 3. ALB listener and target
group health. 4. Backend EC2 security group inbound rule from the ALB
security group. 5. Backend service status and logs. 6. Backend database
connectivity and RDS security group.

### ALB target is unhealthy

* Confirm the backend process is running.
* Confirm the configured health-check path returns the expected
response.
* Confirm the target port matches the backend listener.
* Confirm the backend security group allows traffic from the ALB
security group.
* Inspect target health reason codes and backend logs.

### SSM cannot connect to the instance

* Confirm the instance is running.
* Confirm the instance profile/role is attached and includes the
required SSM permissions.
* Confirm SSM Agent is installed and running.
* Confirm interface endpoints exist in the correct VPC/subnets and
have private DNS enabled as required.
* Confirm endpoint security groups permit TCP 443 from the instance.
* Confirm route tables and endpoint policies are correct.

### Backend cannot connect to RDS

* Confirm the RDS endpoint and port in the backend runtime
configuration without exposing credentials.
* Confirm RDS is available.
* Confirm the RDS security group allows TCP 5432 from the backend
security group.
* Confirm database name/user permissions and SSL settings as required.
* Check backend logs without printing secrets.

## 16\. Project status and known limitations

\---

Area                                Recorded status

\---

VPC and subnet architecture         Implemented

Public ALB and private backend      Implemented
placement

Private RDS architecture            Implemented

Private S3 frontend origin          Implemented

CloudFront and OAC                  Implemented

`/api/\*` routing to ALB             Implemented

SSM access to private EC2           Implemented

GitHub Actions validation           Passed in the recorded run

GitHub OIDC deployment role         Configured

Frontend CRUD                       Tested successfully

Backend deployment through SSM      Implemented in pipeline

Health checks and rollback handling Included in deployment workflow

CloudWatch Agent                    Installed/configured during
troubleshooting



