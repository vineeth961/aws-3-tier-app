# TaskFlow --- AWS Three-Tier Application with DevOps Automation

A cost-conscious AWS three-tier deployment project demonstrating cloud
networking, private infrastructure, CI/CD automation, secure
GitHub-to-AWS authentication, and application delivery through
CloudFront and an Application Load Balancer.

## Architecture at a glance

``` text
                         Users
                           |
                           v
                    Amazon CloudFront
                     /             \\
          Frontend requests       /api/\*
                  |                 |
                  v                 v
          Private S3 origin    Application Load Balancer
          (via CloudFront OAC)       |
                                     v
                              Private EC2 instance
                              TaskFlow backend
                                     |
                                     v
                              Private PostgreSQL
                                  Amazon RDS
```

The frontend is stored in a private S3 bucket. CloudFront serves it
using Origin Access Control (OAC). API requests under `/api/\*` are
routed to an Application Load Balancer (ALB), which forwards traffic to
the backend EC2 instance in a private subnet. The backend connects to a
private RDS PostgreSQL database.

## Main technologies

\---

Area                                Technologies

\---

Cloud                               AWS

Infrastructure                      Terraform

Networking                          VPC, public/private subnets, route
tables, Internet Gateway, security
groups, VPC endpoints

Compute                             Amazon EC2, Ubuntu 24.04

Load balancing                      Application Load Balancer

Database                            Amazon RDS for PostgreSQL

Frontend hosting                    Amazon S3

CDN and routing                     Amazon CloudFront

Secure origin access                CloudFront Origin Access Control
(OAC)

CI/CD                               GitHub Actions

AWS authentication from GitHub      GitHub OIDC, AWS IAM, STS

Private instance management         AWS Systems Manager (SSM)

Monitoring                          Amazon CloudWatch, CloudWatch Agent

Backend service                     systemd
(`taskflow-backend.service`)
---

## Repository

[Open the GitHub
repository](https://github.com/vineeth961/aws-3-tier-app)

## Key project features

* Infrastructure provisioned with Terraform.
* Network separation between public entry points, private application
compute, and private database resources.
* Frontend hosted in a private S3 bucket and delivered through
CloudFront.
* CloudFront routes `/api/\*` requests to the ALB.
* Backend runs on a private EC2 instance and is managed through SSM.
* PostgreSQL database hosted privately on Amazon RDS.
* GitHub Actions validates changes with frontend checks and backend
integration tests.
* GitHub Actions uses OIDC to obtain temporary AWS credentials rather
than storing long-lived AWS access keys.
* Backend deployment is performed through SSM Run Command, followed by
health checks and rollback handling.
* Frontend deployment uploads build output to S3 and refreshes
CloudFront content.

## Deployment workflow

1. A change is pushed to GitHub or a pull request is opened.
2. GitHub Actions runs the applicable validation jobs.
3. Pull requests run validation but do not deploy to AWS.
4. A deployment from the protected `main` branch can assume the AWS
deployment role through OIDC.
5. The frontend build is uploaded to the frontend S3 bucket and
CloudFront cache is refreshed.
6. The backend deployment is initiated on the private EC2 instance
through SSM.
7. Health checks are used to validate the deployment; the workflow
includes rollback handling.

See [the complete project documentation](PROJECT_DOCUMENTATION.md)
for implementation details, setup guidance, screenshots to capture, and
troubleshooting.

## Documentation

* [Complete implementation and handover
guide](PROJECT_DOCUMENTATION.md)

## Important notes

* This project is a learning and portfolio implementation. Do not
describe it as fully production-hardened without additional
security, resilience, backup/restore, monitoring, and operational
validation.
* The current architecture uses one backend EC2 instance. The ALB
provides an entry point, but one target does not provide
application-level high availability.
* The private EC2 instance was deliberately configured without a NAT
Gateway to control costs. SSM and S3 access use VPC endpoints.
Review AWS pricing and remove resources when they are no longer
needed.

## 

