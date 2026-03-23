#!/bin/bash

# Run AWS Glue Sample Data Generator Job
# This script starts a Glue job run and optionally monitors progress

set -e  # Exit on error

# Configuration
PROFILE="king008"
REGION="eu-west-2"
JOB_NAME_PREFIX="glue-engineering-development-sample-data-generator"

echo "🎯 Starting AWS Glue Job"
echo "========================"
echo ""

# Get AWS Account ID (for reference)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile ${PROFILE} --region ${REGION})
echo "Account: $ACCOUNT_ID"
echo "Profile: $PROFILE"
echo "Job Name: $JOB_NAME_PREFIX"
echo ""

# Start the job
echo "🚀 Starting job run..."
RUN_ID=$(aws glue start-job-run \
    --job-name $JOB_NAME_PREFIX \
    --profile $PROFILE \
    --region $REGION \
    --query 'JobRunId' \
    --output text)

echo "✓ Job started!"
echo ""
echo "Job Run ID: $RUN_ID"
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
            --query 'JobRun.[State,ExecutionTime]' \
            --output text)
        
        STATE=$(echo $STATUS | awk '{print $1}')
        EXEC_TIME=$(echo $STATUS | awk '{print $2}')
        
        echo "State: $STATE | Execution Time: ${EXEC_TIME}s"
        
        if [[ "$STATE" == "SUCCEEDED" || "$STATE" == "FAILED" || "$STATE" == "TIMEOUT" ]]; then
            echo ""
            echo "Job finished with state: $STATE"
            break
        fi
        
        sleep 10
    done
else
    echo "View job status with:"
    echo "aws glue get-job-run --job-name $JOB_NAME_PREFIX --run-id $RUN_ID --profile $PROFILE --region $REGION"
fi

echo ""
echo "📋 View logs in CloudWatch:"
echo "   Log Group: /aws-glue/python-jobs"
echo "   Log Stream: $JOB_NAME_PREFIX"
