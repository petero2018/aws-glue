#!/bin/bash

# Run Glue Job with Optional Format Override
# This script starts a Glue job run with optional format parameter
# Usage: ./run_glue_job_with_format.sh [parquet|iceberg]

set -e

# Configuration
PROFILE="king008"
REGION="eu-west-2"
JOB_NAME_PREFIX="glue-engineering-development-sample-data-generator"

# Get format from parameter or use default (iceberg)
FORMAT="${1:-iceberg}"

# Validate format
if [[ ! "$FORMAT" =~ ^(parquet|iceberg)$ ]]; then
    echo "❌ Invalid format: $FORMAT"
    echo "Usage: ./run_glue_job_with_format.sh [parquet|iceberg]"
    exit 1
fi

echo "🎯 Starting AWS Glue Job"
echo "========================"
echo ""

# Get AWS Account ID (for reference)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE} --region ${REGION})
FORMAT_UPPER=$(echo "$FORMAT" | tr '[:lower:]' '[:upper:]')
echo "Account: $ACCOUNT_ID"
echo "Profile: $PROFILE"
echo "Job Name: $JOB_NAME_PREFIX"
echo "Format: $FORMAT_UPPER"
echo ""

# Start the job with format override
echo "🚀 Starting job run..."
RUN_ID=$(aws glue start-job-run \
    --job-name $JOB_NAME_PREFIX \
    --profile $PROFILE \
    --region $REGION \
    --arguments="--OUTPUT_FORMAT=$FORMAT" \
    --query 'JobRunId' \
    --output text)

echo "✓ Job started!"
echo ""
echo "Job Run ID: $RUN_ID"
echo "Format: $FORMAT_UPPER"
echo ""

# Ask if user wants to monitor
read -p "Do you want to monitor job progress? (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "📊 Monitoring job progress..."
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Poll job status
    while true; do
        STATUS=$(aws glue get-job-run \
            --job-name $JOB_NAME_PREFIX \
            --run-id $RUN_ID \
            --profile $PROFILE \
            --region $REGION \
            --query 'JobRun.JobRunState' \
            --output text)
        
        EXECUTION_TIME=$(aws glue get-job-run \
            --job-name $JOB_NAME_PREFIX \
            --run-id $RUN_ID \
            --profile $PROFILE \
            --region $REGION \
            --query 'JobRun.ExecutionTime' \
            --output text 2>/dev/null || echo "0")
        
        printf "\rState: %-10s | Execution Time: %ss" "$STATUS" "$EXECUTION_TIME"
        
        if [[ "$STATUS" == "SUCCEEDED" ]] || [[ "$STATUS" == "FAILED" ]]; then
            echo ""
            echo ""
            if [[ "$STATUS" == "SUCCEEDED" ]]; then
                echo "✅ Job finished with state: $STATUS"
            else
                echo "❌ Job finished with state: $STATUS"
            fi
            break
        fi
        
        sleep 5
    done
else
    echo "Job is running in the background."
    echo "Monitor progress with:"
    echo "  aws glue get-job-run --job-name $JOB_NAME_PREFIX --run-id $RUN_ID --profile $PROFILE --region $REGION"
fi

echo ""
echo "📋 View logs:"
echo "  aws logs tail /aws-glue/python-jobs --follow --profile $PROFILE --region $REGION"
