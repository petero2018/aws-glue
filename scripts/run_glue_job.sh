#!/bin/bash

# Start and monitor Glue jobs created by Terraform.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPTS_DIR/project_config.sh"

INFRA_DIR="$PROJECT_ROOT/infra"
POLL_SECONDS="${GLUE_JOB_POLL_SECONDS:-15}"

require_aws_identity

terraform_output() {
    terraform -chdir="$INFRA_DIR" output -raw "$1"
}

ICEBERG_JOB="$(terraform_output glue_job_name)"
PARQUET_JOB="$(terraform_output glue_job_parquet_name)"
S3TABLES_JOB="$(terraform_output glue_s3tables_job_name)"

start_and_wait() {
    local job_name="$1"
    local run_id
    local state

    echo ""
    echo "Starting Glue job: $job_name"
    run_id=$(aws glue start-job-run \
        --job-name "$job_name" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query JobRunId \
        --output text)
    echo "Run ID: $run_id"

    while true; do
        state=$(aws glue get-job-run \
            --job-name "$job_name" \
            --run-id "$run_id" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --query 'JobRun.JobRunState' \
            --output text)

        echo "  $job_name: $state"
        case "$state" in
            SUCCEEDED)
                echo "✓ Completed: $job_name"
                return 0
                ;;
            FAILED|TIMEOUT|STOPPED|ERROR)
                echo "❌ Glue job failed: $job_name ($state)" >&2
                return 1
                ;;
        esac

        sleep "$POLL_SECONDS"
    done
}

run_menu() {
    echo ""
    echo "Glue Pipelines — choose what to run"
    echo "===================================="
    echo "1) Iceberg sample data generator"
    echo "2) Parquet generator + crawler"
    echo "3) S3 Tables pipeline"
    echo "4) Full chain (Iceberg -> Parquet -> S3 Tables)"
    echo "9) Back"
    echo ""
    read -r -p "Select an option: " choice

    case "$choice" in
        1)
            start_and_wait "$ICEBERG_JOB"
            ;;
        2)
            start_and_wait "$PARQUET_JOB"
            ;;
        3)
            start_and_wait "$S3TABLES_JOB"
            ;;
        4)
            start_and_wait "$ICEBERG_JOB"
            start_and_wait "$PARQUET_JOB"
            start_and_wait "$S3TABLES_JOB"
            ;;
        9)
            exit 0
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
}

echo "Configured Glue jobs:"
echo "  Iceberg : $ICEBERG_JOB"
echo "  Parquet : $PARQUET_JOB"
echo "  S3 Tables: $S3TABLES_JOB"
run_menu
