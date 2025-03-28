import json
from datetime import datetime, timedelta
from collections import defaultdict
import boto3
from botocore.exceptions import NoCredentialsError, PartialCredentialsError
import pandas as pd
import requests
import sys
import os


def read_config(config_file):
    try:
        with open(config_file, 'r') as file:
            return json.load(file)
    except FileNotFoundError:
        print(f"Error: Configuration file '{config_file}' not found.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON format in configuration file '{config_file}'.")
        sys.exit(1)

# def read_portal_ip_from_env():
#     protocol = os.environ.get('PROTOCOL')
#     portal_ip = os.environ.get('PORTAL_IP')

#     if protocol and portal_ip:
#         return protocol.lower(), portal_ip
#     else:
#         print("Error: Missing environment variable 'PROTOCOL' or 'PORTAL_IP'.")
#         sys.exit(1)

def read_portal_ip_from_file(file_path):
    try:
        protocol = None
        portal_ip = None
        with open(file_path, 'r') as file:
            for line in file:
                line = line.strip()
                if line.startswith("protocol"):
                    protocol = line.split("=")[1].strip()
                elif line.startswith("portal_ip"):
                    portal_ip = line.split("=")[1].strip()
        if protocol and portal_ip:
            return protocol.lower(), portal_ip
        else:
            print("Error: Missing 'protocol' or 'portal_ip' in the configuration file.")
            sys.exit(1)
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading portal IP file: {e}")
        sys.exit(1)


def read_logs_from_cloudwatch(log_group_name, start_time, end_time, region):
    try:
        # Create a boto3 client for CloudWatch Logs
        client = boto3.client('logs', region_name=region)

        # Define the paginator to handle log streams
        paginator = client.get_paginator('filter_log_events')

        # Define the query parameters
        query_params = {
            'logGroupName': log_group_name,
            'startTime': int(start_time.timestamp() * 1000),  # Convert to milliseconds
            'endTime': int(end_time.timestamp() * 1000)  # Convert to milliseconds
        }

        # Iterate over paginated results
        events = []
        for page in paginator.paginate(**query_params):
            events.extend(page.get('events', []))
        return [event['message'] for event in events]

    except NoCredentialsError:
        print("Error: AWS credentials not found. Please configure your AWS CLI or provide credentials.")
        sys.exit(1)
    except PartialCredentialsError as e:
        print(f"Error: Incomplete AWS credentials provided: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def get_current_hour_times():
    """Calculate the start and end times for the current hour."""
    now = datetime.now()
    start_time = now.replace(minute=0, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=1) - timedelta(seconds=1)
    return start_time, end_time

# def process_timestamp(raw_timestamp):
#     # Convert log timestamp to the start of the hour
#     dt = datetime.strptime(raw_timestamp.split(" ")[0], "%d/%b/%Y:%H:%M:%S")
#     dt = dt.replace(minute=0, second=0, microsecond=0)
#     return dt.strftime("%Y-%m-%d %H:%M:%S")

def process_timestamp(raw_timestamp):
    try:
        # Parse CloudWatch log timestamp format
        dt = datetime.strptime(raw_timestamp.split(" ")[0], "%d/%b/%Y:%H:%M:%S")
        dt = dt.replace(minute=0, second=0, microsecond=0)  # Round to start of hour
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except ValueError as e:
        print(f"Error processing timestamp '{raw_timestamp}': {e}")
        return "1970-01-01 00:00:00"  # Default fallback timestamp

def load_pricing_sheet(pricing_file):
    try:
        pricing_data = pd.read_csv(pricing_file)
        # Create dictionaries for endpoint to API and price mapping
        endpoint_to_api = dict(zip(pricing_data['Endpoint'], pricing_data['API']))
        endpoint_to_price = dict(zip(pricing_data['Endpoint'], pricing_data['Price']))
        return endpoint_to_api, endpoint_to_price
    except FileNotFoundError:
        print(f"Error: Pricing sheet file '{pricing_file}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error loading pricing sheet: {e}")
        sys.exit(1)

def process_logs(logs, endpoint_to_api, endpoint_to_price):
    output = []
    aggregated_logs = defaultdict(lambda: defaultdict(int))
    latency_sums = defaultdict(int)
    revenue_sums = defaultdict(float)

    for log in logs:
        # Map fields
        timestamp_interval = process_timestamp(log.get("timestamp", "01/Jan/1970:00:00:00 +0000"))
        customer_name = log.get("carrierName", "-") if log.get("carrierName", "-") != "-" else "Unknown"
        client = log.get("client_id", "-") if log.get("client_id", "-") != "-" else "Unknown"
        carrier_name = log.get("customerName", "-") if log.get("customerName", "-") != "-" else "Unknown"
        endpoint = log.get("resourcePath", "Unknown")


        # Map endpoint to API and price using the pricing sheet, default to "Unknown" and 0
        attribute = endpoint_to_api.get(endpoint, "Unknown")

        #price = float(endpoint_to_price.get(endpoint, 0))
        # Ensure price is a valid float
        price = endpoint_to_price.get(endpoint, 0)
        try:
            price = float(price) if str(price).replace('.', '', 1).isdigit() else 0.0
        except ValueError:
            price = 0.0


        # Unique key for aggregation
        unique_key = (timestamp_interval, customer_name, client, carrier_name, attribute)

        # Increment status counts and calculate revenue
        status = log.get("status", "other_non_200")
        if status == "200":
            aggregated_logs[unique_key]["200"] += 1
            revenue_sums[unique_key] += price
            try:
                latency_sums[unique_key] += int(log.get("responseLatency", 0) if log.get("responseLatency", "-").isdigit() else 0)
            except ValueError:
                latency_sums[unique_key] += 0
        elif status == "404":
            aggregated_logs[unique_key]["404"] += 1
        else:
            aggregated_logs[unique_key]["other_non_200"] += 1

    # Convert aggregated logs to output format
    for (timestamp_interval, customer_name, client, carrier_name, attribute), status_counts in aggregated_logs.items():
        total_200_count = status_counts.get("200", 0)
        avg_latency = latency_sums[(timestamp_interval, customer_name, client, carrier_name, attribute)] // total_200_count if total_200_count > 0 else 0
        # est_revenue = revenue_sums[(timestamp_interval, customer_name, client, carrier_name, attribute)]
        est_revenue = revenue_sums.get((timestamp_interval, customer_name, client, carrier_name, attribute), 0.0)


        # Create analytical_id
        analytical_id = f"{customer_name}|{client}|{carrier_name}|{attribute}"

        result = {
            "timestamp_interval": timestamp_interval,
            "customer_name": customer_name,
            "client": client,
            "carrier_name": carrier_name,
            "attribute": attribute,
            "status_counts": {
                "200": status_counts.get("200", 0),
                "404": status_counts.get("404", 0),
                "other_non_200": status_counts.get("other_non_200", 0),
            },
            "avg_latency_ms": avg_latency,
            "est_revenue": est_revenue,
            "analytical_id": analytical_id
        }
        output.append(result)

    return output

# Example usage
def lambda_handler(event, context):
    # Your script content goes here. For example:
    config_file = 'config.json'
    pricing_file = 'api_pricing.csv'
    portal_ip_file = 'portal_api_config.cfg'

    # Read configuration
    config = read_config(config_file)
    log_group_name = config.get("log_group_name")

    # Validate log group name
    if not log_group_name:
        print("Error: Log group name is missing in the configuration file.")
        sys.exit(1)

    # Load pricing sheet
    endpoint_to_api, endpoint_to_price = load_pricing_sheet(pricing_file)

    # Read portal IP and protocol
    protocol, portal_ip = read_portal_ip_from_file(portal_ip_file)
    api_url = f"{protocol}://{portal_ip}/analytics/node/add"
    print("api_url", api_url)

    # Calculate start and end times for the current hour
    start_time, end_time = get_current_hour_times()
    print(f"Fetching logs from {start_time} to {end_time} for log group: {log_group_name}")

    # Fetch logs
    cloudwatch_logs = read_logs_from_cloudwatch(log_group_name, start_time, end_time, region="ap-southeast-1")

    # Process logs
    logs = [json.loads(log) for log in cloudwatch_logs]
    output_data = process_logs(logs, endpoint_to_api, endpoint_to_price)

    # Send the payload to the API endpoint
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Basic YWRtaW46cGFzcw=="
    }

    try:
        response = requests.post(api_url, headers=headers, json=output_data, timeout=10)

        success_status = "success" if response.status_code == 200 else "not-success"
        print(f"API Call Status: {success_status}, Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Response Status Code: {response.status_code}")
        print(f"Response Headers: {response.headers}")
        print(f"Response Body: {response.text}")
    except requests.exceptions.Timeout:
        print(f"Error: API call to {api_url} timed out.")
    except requests.exceptions.RequestException as e:
        print(f"Error: An error occurred during the API call: {e}")