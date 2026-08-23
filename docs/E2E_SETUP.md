# End-to-end setup: AWS Glue Iceberg to Snowflake

This is the complete first-time flow for the development environment. The
order matters because Snowflake needs the AWS resources and Glue tables before
the linked database and governance layer can be created.

## Before you start

Make sure that:

- the AWS CLI profile is configured in `~/.aws/config` and/or
  `~/.aws/credentials`;
- Terraform is installed and the account has the permissions described in
  [AWS_BOOTSTRAP.md](AWS_BOOTSTRAP.md);
- the Snowflake account has `COMPUTE_WH`;
- masking policies are supported by the Snowflake edition in use
  (Enterprise or higher).

The project stores only non-secret AWS settings in `.aws-glue.local`. AWS
credentials and SSO tokens remain in the normal AWS CLI configuration.

When menu option `2` or `4` finishes, the terminal prints an
account-specific AWS → Snowflake hand-off summary. It includes the generated
bucket, Glue database, both Snowflake role ARNs, the exact `DESC` checkpoints,
and the trust-policy value mapping. The same output can be printed later with:

```bash
bash scripts/show_snowflake_next_steps.sh
```

## 1. Run the AWS setup flow

Start the menu from the repository root:

```bash
bash scripts/menu.sh
```

Run these options in order:

### `0` — Setup AWS

Select the AWS CLI profile, region, environment and project name. The script
validates the account when possible and writes `.aws-glue.local`.

### `1` — Bootstrap State Backend

Run this once for the account. It creates the Terraform state S3 bucket and
DynamoDB lock table.

### `2` — Deploy Infrastructure

Approve the Terraform plan only after checking the plan. This creates the S3
bucket, Glue Catalog databases, IAM roles and policies, the explicit Lake
Formation grants required by Glue Iceberg `createOrReplace`, Athena resources,
and the optional VPC/S3 Tables resources.

Terraform also registers the active AWS deploy identity as a Lake Formation
data lake administrator. This is required so Terraform can grant the Glue
service role permissions on future Iceberg tables when the AWS profile uses an
SSO or assumed role identity.

Keep `enable_msk = false` for this development flow unless MSK is explicitly
required. MSK Serverless is billable.

### `3` — Upload Glue Scripts to S3

This uploads the Python job code used by the Glue jobs.

### `7` — Generate Snowflake SQL

This step must happen after infrastructure deployment. It reads the active AWS
identity and Terraform outputs, then creates the account-specific files:

```text
snowflake/setup_raw_iceberg.local.sql
snowflake/setup_glue_raw_iceberg_roles_and_masking.local.sql
snowflake/setup_complex_types_pii_masking.local.sql
snowflake/setup_dynamic_object_pii_masking.local.sql
snowflake/setup_iceberg_property_pii_poc.local.sql
snowflake/destroy_glue_raw_iceberg.local.sql
```

There is one universal raw Iceberg linked database. It discovers every table
in the Terraform-created Glue database, including `complex_types_poc` and
`pii_column_metadata`; no table-specific linked database SQL is required.

Do not execute the `.sql` templates directly. Execute the generated `.local.sql`
files. If the AWS profile, Terraform state or outputs change, run option `7`
again before using the files.

The complete cross-system configuration is also available from Terraform:

```bash
terraform -chdir=infra output snowflake_raw_iceberg_config
```

This contains the bucket URI, Glue database and catalog endpoint, AWS role
ARNs, Snowflake warehouse and the three shared Snowflake object names. The
Snowflake-generated IAM user ARNs and external IDs are intentionally absent;
they only exist after the corresponding `DESC` statements.

Recommended order after menu option `2`:

1. Run menu option `3` to upload the Glue scripts.
2. Run menu option `7` to render the account-specific SQL.
3. Complete section 2 below to create the universal Snowflake link and update
   both AWS trust policies.
4. Run menu option `6` and choose the Iceberg pipeline(s) you need.
5. Wait for catalog discovery, then run the optional governance SQL files.

### `6` — Run Glue Pipelines

Run this after the universal raw Iceberg linked database is created, unless
you intentionally want to create the tables first and let discovery catch up
later. The linked database is namespace-level, so no new Snowflake setup is
needed for any of the pipeline choices below.

Choose option `1` in the submenu:

```text
1) Iceberg sample data generator
```

Wait for the job to finish successfully. This creates the Iceberg metadata and
tables in the Glue database and writes data under the generated bucket's
`raw-iceberg/` prefix. The Parquet and S3 Tables pipelines are optional for the
Snowflake linked-database setup.

For the table-property PII proof of concept, choose option `5` instead:

```text
5) Iceberg PII table-property POC
```

To reproducibly create both PII POC tables and rebuild the complete metadata
table in one sequential run, choose option `7`:

```text
7) Rebuild PII metadata POCs (employee + complex)
```

This creates the separate `employee_directory_poc` Iceberg table in the same
Glue database and at:

```text
s3://<generated-bucket>/raw-iceberg/employee_directory_poc/
```

The table has ten synthetic columns. `first_name`, `last_name`, `email` and
`phone` are classified as `PII` or `UNCLASSIFIED_PII`; the other columns are
classified as `NONE`. The classification is stored in the Iceberg metadata
property `governance.pii.classification` as a JSON column-to-classification
map. This job intentionally does not write PII information to column
descriptions.

The PII and complex-type POC jobs share the Iceberg metadata table
`pii_column_metadata` at:

```text
s3://<generated-bucket>/raw-iceberg/pii_column_metadata/
```

Each job rebuilds the same deterministic set containing one row for each
`PII` or `UNCLASSIFIED_PII` column. After either POC job completes, the table
contains the expected rows for both `employee_directory_poc` and
`complex_types_poc`; reruns do not depend on the previous table contents. Its
schema is:

```text
id, catalog, schema, table, column, pii_tag_key, pii_tag_value,
description, create_datetime
```

The `catalog` value is passed from Terraform as the active AWS Glue catalog
ID; it is not hardcoded in the Glue script.

For the nested Iceberg type proof of concept, choose submenu option `6`:

```text
6) Iceberg complex data types POC (Array, Map, Struct)
```

This creates `complex_types_poc` in the same Glue database and at:

```text
s3://<generated-bucket>/raw-iceberg/complex_types_poc/
```

The table contains an integer `id`, an `ArrayType` column (`tags`), a
`MapType` column (`attributes`) and a nested `StructType` column (`profile`).
In Iceberg terminology these are a list, map and struct respectively. The
The `tags`, `attributes` and `profile` columns are synthetic PII test columns;
`id` is classified as `NONE`. The complex job also rebuilds the complete
classification set in `pii_column_metadata`. The table is picked up by the existing Snowflake
catalog-linked database after its next discovery sync.

## 2. Configure the universal raw Iceberg link

Open:

```text
snowflake/setup_raw_iceberg.local.sql
```

This is the foundation SQL for all tables under the AWS Glue database and
`s3://<generated-bucket>/raw-iceberg/`. It creates exactly one shared external
volume, one AWS Glue Iceberg REST catalog integration and one read-only linked
database. It contains no table names.

> Important: SQL comments do not pause Snowflake execution. Do not select and
> run the entire `.local.sql` file in one go. Stop after each `DESC` checkpoint,
> update the corresponding AWS IAM trust policy, and only then continue.

### 2.1 Create the external volume and update its trust policy

Run section `1` through:

```sql
DESC EXTERNAL VOLUME GLUE_RAW_ICEBERG_VOLUME;

SELECT
  TRY_PARSE_JSON("property_value"):STORAGE_AWS_IAM_USER_ARN::STRING,
  TRY_PARSE_JSON("property_value"):STORAGE_AWS_EXTERNAL_ID::STRING
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE UPPER("property") = 'STORAGE_LOCATION_1';
```

Copy these two values from the result:

- `STORAGE_AWS_IAM_USER_ARN`
- `STORAGE_AWS_EXTERNAL_ID`

Update the trust relationship of the generated S3 role with those values:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "<STORAGE_AWS_IAM_USER_ARN>"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID>"
        }
      }
    }
  ]
}
```

Use the returned IAM user directly as `Principal.AWS`. Do not use the AWS
account root and do not add an `aws:PrincipalArn` condition when using the
direct user principal.

Use the role ARN printed in the generated SQL. Do not use the catalog role and
do not use the `API_AWS_*` values for this role.

The ARN is also available directly from Terraform:

```bash
terraform -chdir=infra output snowflake_raw_iceberg_s3_role_arn
```

The S3 read/list identity policy is already attached by Terraform. No manual
policy attachment is required.

### 2.2 Verify the external volume

After the S3 trust policy is updated, run:

```sql
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('GLUE_RAW_ICEBERG_VOLUME');
```

Continue only when `awsRoleArnValidationResult` is `PASSED`. A read-only
volume may report write/read/list/delete as `UNVERIFIED` because writes are
disabled.

### 2.3 Create the Glue Iceberg REST catalog integration

Run the catalog integration section through:

```sql
DESC CATALOG INTEGRATION GLUE_RAW_ICEBERG_CATALOG_INT;

SELECT
  UPPER("property") AS PROPERTY,
  "property_value" AS PROPERTY_VALUE
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE UPPER("property") IN (
  'API_AWS_IAM_USER_ARN',
  'API_AWS_EXTERNAL_ID'
);
```

For an AWS Glue Iceberg REST integration, the generated query extracts:

- `API_AWS_IAM_USER_ARN`
- `API_AWS_EXTERNAL_ID`

Update the trust relationship of the generated Glue catalog role with these
values. This is a different AWS role from the external-volume role.

Its ARN is available directly from Terraform:

```bash
terraform -chdir=infra output snowflake_raw_iceberg_catalog_role_arn
```

Use the returned `API_AWS_IAM_USER_ARN` directly as `Principal.AWS`. Do not
use the AWS account root, the S3 role's `STORAGE_AWS_*` values, or the
`SNOWFLAKE_TRUST_NOT_CONFIGURED` placeholders.

Do not reuse the `STORAGE_AWS_*` values. Do not use the AWS account root as the
Snowflake principal. Terraform already attaches the Glue catalog and S3 read
policies to this role. No manual AWS permission-policy attachment is needed.

If the filtered `DESC` query returns no rows, first run the raw command:

```sql
DESC CATALOG INTEGRATION GLUE_RAW_ICEBERG_CATALOG_INT;
```

Confirm that the integration is an AWS Glue integration and inspect the exact
property names before changing IAM. Do not guess or hardcode the values.

### 2.4 Create the universal linked database

After the catalog role trust policy is updated, run the grants and linked
database section. The linked database section uses `SYSADMIN` and creates:

```text
GLUE_RAW_ICEBERG
```

Verify the link:

```sql
SELECT SYSTEM$GET_CATALOG_LINKED_DATABASE_CONFIG('GLUE_RAW_ICEBERG');
SELECT SYSTEM$CATALOG_LINK_STATUS('GLUE_RAW_ICEBERG');
SHOW SCHEMAS IN DATABASE GLUE_RAW_ICEBERG;
SHOW TABLES IN SCHEMA GLUE_RAW_ICEBERG."raw_iceberg_development";
```

`executionState = RUNNING` means that discovery is scheduled or in progress;
it does not guarantee that every table is visible yet. Wait for the next sync
and refresh the database explorer. If the schema remains empty, force a new
discovery run:

```sql
ALTER DATABASE GLUE_RAW_ICEBERG RESUME DISCOVERY;
```

Then verify that the expected tables exist in the AWS Glue database as well.
Snowflake cannot display a table that the Glue job did not successfully create
or that was written to a different Glue database/namespace. New tables in the
same Glue database and `raw-iceberg/` prefix do not require another Snowflake
integration, external volume or linked database.

## 3. Create Snowflake roles, tags and masking

Open:

```text
snowflake/setup_glue_raw_iceberg_roles_and_masking.local.sql
```

Run the complete file after the linked database has synchronized.

The script:

1. creates `GLUE_GOVERNANCE.CLASSIFICATION.PII`;
2. creates the masked and PII reader roles;
3. grants read-only access to `GLUE_RAW_ICEBERG` and `COMPUTE_WH`;
4. creates role-aware STRING, NUMBER, DATE, ARRAY, MAP and VARIANT masking
   policies;
5. attaches those masking policies to the `PII` tag by data type.

This file defines reusable governance objects only. It does not discover or
tag table columns. The later metadata-driven association flow applies the
`PII` tag to the selected columns in `pii_column_metadata`.

The script does not grant either reader role to a Snowflake user. Do that only
after reviewing the access model, using `SECURITYADMIN`:

```sql
GRANT ROLE GLUE_RAW_ICEBERG_READER TO USER <MASKED_USER>;
GRANT ROLE GLUE_RAW_ICEBERG_PII_READER TO USER <APPROVED_PII_USER>;
```

Test with explicit active roles:

```sql
USE ROLE GLUE_RAW_ICEBERG_READER;
SELECT *
FROM GLUE_RAW_ICEBERG."raw_iceberg_development"."customers"
LIMIT 10;

USE ROLE GLUE_RAW_ICEBERG_PII_READER;
SELECT *
FROM GLUE_RAW_ICEBERG."raw_iceberg_development"."customers"
LIMIT 10;
```

The first query must mask PII after the metadata-driven tag association has
been run; the second may show the original values.

For the complex-type table, run the separate generated association file:

```text
snowflake/setup_complex_types_pii_masking.local.sql
```

It reads `pii_column_metadata`, filters to the active account,
`raw_iceberg_development.complex_types_poc`, and applies the existing `PII`
tag to matching columns. The current metadata generator writes rows for the
property POC table; if it returns zero matching rows for `complex_types_poc`,
that table must first be represented in `pii_column_metadata`.

For PII columns whose Iceberg type is a structured `OBJECT`, run:

```text
snowflake/setup_dynamic_object_pii_masking.local.sql
```

This process discovers the complete OBJECT signature from the linked table and
creates a deterministic, column-specific masking policy. The policy returns
the complete object for `GLUE_RAW_ICEBERG_PII_READER` and `NULL` for the normal
reader role. It does not run `UNSET` or `DROP` automatically. If a direct
policy with an older OBJECT signature is already attached, the output contains
the exact migration statements to review and run manually.

## 4. Run the table-property PII POC in Snowflake

After the POC Glue job has completed and the linked database has synchronized,
run the generated file:

```text
snowflake/setup_iceberg_property_pii_poc.local.sql
```

This separate property-based proof of concept creates a narrowly scoped
external stage over only the POC table's Iceberg `metadata/` prefix, reads the
latest metadata JSON, parses `governance.pii.classification`, and applies the
`GLUE_GOVERNANCE.CLASSIFICATION.PII_CLASSIFICATION` tag to all ten columns.
The tag values are exactly `NONE`, `UNCLASSIFIED_PII` and `PII`. Its
tag-based masking policies preserve `NONE`, mask the two PII states for the
normal reader role, and reveal the synthetic values only for the explicit PII
reader role.

The script contains a second `DESC STORAGE INTEGRATION` pause. Add the
returned Snowflake principal and external ID as an additional statement in
the trust policy of the existing Terraform-created S3 role, then continue.
This trust update is intentionally ignored by Terraform's lifecycle policy.

## 5. Useful diagnostics

Check the active Snowflake role when masking results are unexpected:

```sql
SELECT
  CURRENT_ROLE(),
  CURRENT_SECONDARY_ROLES(),
  CURRENT_ROLE() = 'GLUE_RAW_ICEBERG_PII_READER' AS IS_PII_ROLE;
```

An empty result from `SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES` immediately after
tagging is not proof of failure; Account Usage can be delayed. Use the direct
`TAG_REFERENCES_ALL_COLUMNS` query in the generated governance SQL for an
immediate table-level check.

## 6. Destroy/recreate warning

### Snowflake cleanup

Option `7` also renders:

```text
snowflake/destroy_glue_raw_iceberg.local.sql
```

This is the Snowflake-side equivalent of the AWS cleanup. It removes only the
objects created by this repository:

- the `GLUE_RAW_ICEBERG` linked database;
- the `GLUE_RAW_ICEBERG_CATALOG_INT` catalog integration;
- the `GLUE_RAW_ICEBERG_VOLUME` external volume;
- the `GLUE_GOVERNANCE` database, tag and masking policies;
- the `GLUE_RAW_ICEBERG_READER` and `GLUE_RAW_ICEBERG_PII_READER` roles.

It does not drop Snowflake users, `COMPUTE_WH`, or unrelated databases. Review
the `SHOW` results at the start of the file before executing the destructive
statements. Dropping the roles revokes their grants, including grants made
manually to users, but does not delete those users.

The safest teardown order is:

1. run the generated Snowflake cleanup SQL;
2. run the AWS menu option `5` / `destroy_infrastructure.sh`.

A full Terraform destroy removes the IAM roles and resets their manually
configured trust policies. After recreating the infrastructure, repeat both
trust-policy updates using the values in the existing or newly recreated
Snowflake objects, then rerun the external-volume and catalog-link checks.

The Terraform S3 buckets use `force_destroy = true`; a full destroy can delete
the Iceberg, Parquet and Athena-result data. Do not use the destroy flow as a
low-cost pause mechanism unless the data is disposable or backed up.

### Terraform lifecycle behavior

The repository currently uses two different lifecycle mechanisms:

- `lifecycle.ignore_changes = [assume_role_policy]` on the two Snowflake AWS
  roles. This preserves the manually updated Snowflake trust policy during a
  normal `terraform plan/apply`; it does not preserve the policy after the IAM
  role itself is destroyed.
- the Athena-results S3 lifecycle configuration expires old result objects
  after 30 days. This is an AWS data-retention rule, not a Terraform protection
  rule. It does not prevent `terraform destroy` from deleting the bucket.

The S3 buckets also use `force_destroy = true`, and the AWS destroy script
empties them before Terraform removes them. There is currently no
`lifecycle.prevent_destroy` protection on these resources.

For a low-cost pause, review the plan after setting `enable_vpc = false` and
keep `enable_msk = false`. Confirm that only the intended networking resources
are removed before applying.
