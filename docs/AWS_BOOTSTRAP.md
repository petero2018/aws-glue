# AWS Account Bootstrap

This repository does not create IAM users or access keys automatically. That
step must be performed by an AWS account administrator, outside Terraform and
outside this repository. The repository only consumes an already configured AWS
CLI profile.

## Recommended: IAM Identity Center or an assumed role

For human access, AWS recommends federation/IAM Identity Center and temporary
credentials instead of long-lived IAM user access keys. Configure access to
the target account, then authenticate locally with the AWS CLI and select that
profile in the project setup menu.

```bash
aws configure --profile <your profile name>
aws login --profile <your profile name>
aws sts get-caller-identity --profile <your profile name>
```

## Simple local setup: IAM user with access keys

This is acceptable for a personal development account, but is not the
preferred production setup.

An AWS administrator should:

1. Sign in to the intended AWS account and verify the account ID.
2. Create a dedicated IAM user, for example `glue-platform-terraform`.
3. Create a CLI access key for that user and copy the secret immediately; AWS
   only shows the secret access key at creation time.
4. Grant the user permission to manage this stack. For a temporary personal
   development bootstrap, `AdministratorAccess` is the straightforward option.
   For production, replace it with a reviewed custom policy or an assumable
   deployment role.
5. Enable MFA and rotate/delete the access key according to the account's
   security policy.

Do not create root-user access keys, commit credentials, or paste them into
`.aws-glue.local`.

Configure the resulting access key locally:

```bash
aws configure --profile glue-platform
aws sts get-caller-identity --profile glue-platform --region eu-west-2
```

Then run:

```bash
./scripts/menu.sh
# 0) Setup AWS
```

The menu stores only `AWS_PROFILE`, `AWS_REGION`, `environment` and the project
name in the ignored `.aws-glue.local` file.

## Why the Terraform principal needs broad access

This stack provisions more than Glue jobs. It currently manages resources in
S3, S3 Tables, DynamoDB, IAM, VPC/EC2 networking, MSK, Glue, Athena, Lake
Formation, CloudWatch Logs/alarms and Glue Schema Registry. It also creates IAM
service roles and therefore needs permission to pass those roles to AWS
services. The state bootstrap additionally creates the S3 state bucket and the
DynamoDB lock table.

For a production account, use a dedicated deployment role with a permissions
boundary/SCP and refine the policy after reviewing Terraform plan/apply access
logs. Do not casually reduce permissions before checking the first plan: the
deployment will fail in non-obvious places, especially around IAM, Lake
Formation, networking and MSK.

## First-time order

```text
AWS admin creates the user/role and grants access
        ↓
AWS CLI profile is configured locally
        ↓
menu.sh → 0) Setup AWS
        ↓
menu.sh → 1) Bootstrap State Backend
        ↓
menu.sh → 2) Deploy Infrastructure
```

If the project moves to another AWS account, repeat the profile setup. The
Terraform state bucket is account-specific and is regenerated from the
currently authenticated account.

Further reading: [AWS IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html),
[IAM users and credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html),
and [AWS CLI IAM user authentication](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html).
