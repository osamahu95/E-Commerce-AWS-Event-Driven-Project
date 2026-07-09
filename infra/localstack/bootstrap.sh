#!/usr/bin/env bash
# Runs automatically inside the LocalStack container (init hook).
# Provisions the messaging backbone for v1: SNS topic (+ queues, DLQs, filters later).
set -euo pipefail

echo "[bootstrap] creating SNS topic 'order-events'..."

TOPIC_ARN=$(awslocal sns create-topic \
  --name order-events \
  --query 'TopicArn' --output text)

echo "[bootstrap] topic ready: ${TOPIC_ARN}"

echo "[bootstrap] creating SQS queues with their respective DQLs..."

for q in inventory-queue payment-queue completion-queue; do
  awslocal sqs create-queue --queue-name "${q}-dlq" > /dev/null

  DLQ_ARN=$(awslocal sqs get-queue-attributes \
    --queue-url "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/${q}-dlq" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' --output text)

  awslocal sqs create-queue \
    --queue-name "$q" \
    --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"${DLQ_ARN}\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"}" > /dev/null

  echo "[bootstrap]   ${q} -> ${q}-dlq (maxReceiveCount=3)"
done