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
echo "[bootstrap] creating SQS queues with their respective DQLs end..."

echo "[bootstrap] subscribing queues to topic with filter policies..."

TOPIC_ARN="arn:aws:sns:us-east-1:000000000000:order-events"
SQS_BASE="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000"

subscribe() {
  local queue="$1"
  local event_type="$2"

  local queue_arn
  queue_arn=$(awslocal sqs get-queue-attributes \
    --queue-url "${SQS_BASE}/${queue}" \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' --output text)

  local sub_arn
  sub_arn=$(awslocal sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint "$queue_arn" \
    --attributes "RawMessageDelivery=true" \
    --query 'SubscriptionArn' --output text)

  awslocal sns set-subscription-attributes \
    --subscription-arn "$sub_arn" \
    --attribute-name FilterPolicy \
    --attribute-value "{\"type\":[\"${event_type}\"]}"

  echo "[bootstrap]   ${queue} <- ${event_type}"
}

subscribe inventory-queue   OrderCreated
subscribe payment-queue     InventoryReserved
subscribe completion-queue  PaymentCharged

echo "[bootstrap] subscribing queues to topic with filter policies end ...."