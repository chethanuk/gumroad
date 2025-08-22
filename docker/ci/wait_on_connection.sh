#!/bin/bash

set -e

HOST=$1
PORT=$2
TIMEOUT=${3:-30}
SERVICE_NAME=${4:-"service"}

echo "⏳ Waiting for $SERVICE_NAME at $HOST:$PORT (timeout: ${TIMEOUT}s)..."

counter=0
until nc -z "$HOST" "$PORT" 2>/dev/null; do
    counter=$((counter + 1))
    if [ $counter -gt $TIMEOUT ]; then
        echo "❌ Timeout waiting for $SERVICE_NAME at $HOST:$PORT after ${TIMEOUT}s"
        exit 1
    fi
    echo "   Attempt $counter/$TIMEOUT..."
    sleep 1
done

echo "✅ $SERVICE_NAME is ready at $HOST:$PORT"
