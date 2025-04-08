#!/bin/bash

# Variables
LOG_FILE="/usr/local/kong/logs/custom_api_transaction.log"
CSV_FILE="/etc/kong/api_pricing.csv"
API_URL="http://34.172.248.137/analytics/node/add"
AUTH_HEADER="Basic YWRtaW46cGFzcw=="

# Load API mapping from CSV into an associative array
declare -A api_mapping
while IFS=',' read -r available enabled api network endpoint price currency markup bundle_discount wholesale; do
  if [[ "$available" == "TRUE" ]]; then
    api_mapping["$endpoint"]="$api"
  fi
done < <(tail -n +2 "$CSV_FILE") # Skip the header row

# Function to parse logs and prepare JSON payload
prepare_payload() {
  local lines=("$@")
  local payload="["
  local first_entry=true

  for line in "${lines[@]}"; do
    # Extract fields from log
    log_time=$(echo "$line" | grep -oP "Timestamp: \K[^,]+")
    status=$(echo "$line" | grep -oP "Status: \K[^\s,]+")
    method=$(echo "$line" | grep -oP "Method: \K[^\s,]+")
    endpoint=$(echo "$line" | grep -oP "Attribute: \K[^\s,]+")
    carrier_name=$(echo "$line" | grep -oP "Carrier Name: \K[^\s,]+")
    customer_name=$(echo "$line" | grep -oP "Customer Name: \K[^\s,]+")
    client=$(echo "$line" | grep -oP "Client: \K[^\s,]+")
    latency=$(echo "$line" | grep -oP "Latency: \K[^\s]+(?= ms)")
    analytical_uuid=$(uuidgen)

    # Find matching API name for the endpoint
    api_name="${api_mapping[$endpoint]:-Unknown}"

    # Build JSON object
    log_entry=$(cat <<EOF
      {
        "timestamp_interval": "$log_time",
        "customer_name": "$customer_name",
        "client": "$client",
        "carrier_name": "$carrier_name",
        "attribute": "$api_name",
        "method": "$method",
        "status_counts": {
          "$status": 1
        },
        "transaction_type": "unknown",
        "transaction_type_count": 1,
        "avg_latency_ms": $latency,
        "analytical_UUID": "$analytical_uuid"
      }
EOF
    )

    # Append to payload
    if $first_entry; then
      first_entry=false
    else
      payload+=","
    fi
    payload+="$log_entry"
  done

  payload+="]"
  echo "$payload"
}

# Read logs
filtered_logs=()
while IFS= read -r line; do
  filtered_logs+=("$line")
done < "$LOG_FILE"

# Generate payload
payload=$(prepare_payload "${filtered_logs[@]}")

# Write payload to a temporary file
tmp_payload_file=$(mktemp)
echo "$payload" > "$tmp_payload_file"

# Send payload via curl
response=$(curl --write-out "%{http_code}" --silent --output /dev/null \
  --location "$API_URL" \
  --header "Content-Type: application/json" \
  --header "Authorization: $AUTH_HEADER" \
  --data-binary @"$tmp_payload_file")

# Clean up the temporary file
rm -f "$tmp_payload_file"

# Check response
if [[ "$response" == "200" ]]; then
  echo "Post successful"
else
  echo "Post unsuccessful"
fi
