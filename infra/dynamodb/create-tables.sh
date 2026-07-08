#!/usr/bin/env bash
# Runs automatically inside the LocalStack container (init hook).
# Creates DynamoDB tables for v1. Re-runs on every fresh container start.
set -euo pipefail

echo "[create-tables] creating 'orders' table..."

awslocal dynamodb create-table \
  --table-name orders \
  --attribute-definitions AttributeName=order_id,AttributeType=S \
  --key-schema AttributeName=order_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

awslocal dynamodb wait table-exists --table-name orders

echo "[create-tables] 'orders' is ACTIVE. Done."
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo "[create-tables] creating 'outbox' table (with Streams)..."

awslocal dynamodb create-table \
  --table-name outbox \
  --attribute-definitions AttributeName=message_id,AttributeType=S \
  --key-schema AttributeName=message_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_IMAGE

awslocal dynamodb wait table-exists --table-name outbox

echo "[create-tables] 'outbox' is ACTIVE with Streams."