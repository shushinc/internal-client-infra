#!/bin/bash

# Variables
LOG_FILE="/usr/local/kong/logs/custom_api_transaction.log"
CSV_FILE="/etc/kong/aggregates/api_pricing.csv"
# Configuration file path
CONFIG_FILE="/etc/kong/aggregates/portal_api_config.cfg"

# Check if configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Configuration file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Source the configuration file
source "$CONFIG_FILE"

# Validate that PORTAL_API_IP is set
if [[ -z "$PORTAL_API_IP" ]]; then
  echo "Error: PORTAL_API_IP is not set in the configuration file" >&2
  exit 1
fi

# Construct API URL dynamically
API_URL="http://${PORTAL_API_IP}/analytics/node/add"

AUTH_HEADER="Basic YWRtaW46cGFzcw=="

# Load API mapping from CSV into an associative array
declare -A api_mapping
declare -A api_price
while IFS=',' read -r available enabled api network endpoint price currency markup bundle_discount wholesale; do
    if [[ -n "$endpoint" ]]; then
    api_mapping["$endpoint"]="$api"
    # Convert "N/A" to 0 for price
    api_price["$endpoint"]=$(echo "$price" | sed 's/N\/A/1/')
  fi
done < <(tail -n +2 "$CSV_FILE") # Skip the header row

# Function to parse logs and prepare JSON payload
prepare_payload() {
  declare -A aggregation
  local lines=("$@")

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

    # Validate and handle latency (convert invalid values to 0)
    if [[ -z "$latency" || ! "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        latency=0
    fi

    # Find matching API name and price
    api_name="${api_mapping[$endpoint]:-Unknown}"
    price="${api_price[$endpoint]:-0}"

    # Create a unique key
    key="$customer_name|$client|$carrier_name|$api_name|$method"

    # Initialize aggregation entry if not exists
    if [[ -z "${aggregation[$key]}" ]]; then
      aggregation["$key"]=$(jq -n --argjson latency "$latency" --argjson price "$price" '{
        count_200: 0,
        count_404: 0,
        count_others: 0,
        total_latency: $latency,
        transaction_count: 1,
        est_revenue: $price
      }')
    else
      aggregation["$key"]=$(echo "${aggregation["$key"]}" | jq --argjson latency "$latency" --argjson price "$price" \
        '.total_latency += $latency | .transaction_count += 1 | .est_revenue += $price')
    fi

    # Increment status-specific counters
    case "$status" in
      200)
        aggregation["$key"]=$(echo "${aggregation["$key"]}" | jq '.count_200 += 1')
        ;;
      404)
        aggregation["$key"]=$(echo "${aggregation["$key"]}" | jq '.count_404 += 1')
        ;;
      *)
        aggregation["$key"]=$(echo "${aggregation["$key"]}" | jq '.count_others += 1')
        ;;
    esac
  done

  # Prepare JSON payload
  payload="["
  first_entry=true

  for key in "${!aggregation[@]}"; do
    IFS='|' read -r customer_name client carrier_name api_name method <<< "$key"
    aggregated_data=$(echo "${aggregation["$key"]}" | jq --arg customer_name "$customer_name" \
      --arg client "$client" --arg carrier_name "$carrier_name" --arg attribute "$api_name" \
      --arg method "$method" --arg uuid "$key" '{
      timestamp_interval: now | strftime("%Y-%m-%d %H:%M:%S"),
      customer_name: $customer_name,
      client: $client,
      carrier_name: $carrier_name,
      attribute: $attribute,
      method: $method,
      status_counts: {
        "200": .count_200,
        "404": .count_404,
        "other_non_200": .count_others
      },
      avg_latency_ms: (.total_latency / .transaction_count | floor),
      est_revenue: .est_revenue,
      kong_analytical_id: $uuid
    }')

    # Append to payload
    if $first_entry; then
      first_entry=false
    else
      payload+=","
    fi
    payload+="$aggregated_data"
  done

  payload+="]"
  echo "$payload"
}

# Read logs for the current hour
current_time=$(date '+%Y-%m-%d %H:%M:%S')
start_of_hour=$(date '+%Y-%m-%d %H:00:00')

# Filter logs for the current hour
filtered_logs=()
while IFS= read -r line; do
    # Extract the timestamp from the log entry
    log_time=$(echo "$line" | grep -oP "(?<=Timestamp: )\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}")
    
    # Skip lines without a valid timestamp
    if [[ -z "$log_time" ]]; then
        continue
    fi

    # Compare timestamps using `>` and `<` for lexicographical comparison
    if [[ "$log_time" > "$start_of_hour" ]] && [[ "$log_time" < "$current_time" ]]; then
        filtered_logs+=("$line")
    fi
done < "$LOG_FILE"



# Generate payload
payload=$(prepare_payload "${filtered_logs[@]}")

# Validate JSON
echo "Validating JSON payload..."
if echo "$payload" | jq empty; then
  echo "JSON payload is valid."
else
  echo "Error: Invalid JSON payload." >&2
  exit 1
fi

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
