# Deploying deploy 

This guide provides step-by-step instructions to deploy an Amazon EKS cluster using a Terraform module and install **Cert-Manager**, **AWS Load Balancer (ALB) Controller**, and **Karpenter** using **Kustomize**.


## **Step 1: Update terraform.tfvars
1. **Update terraform.tfvars**

    ### Create the S3 Bucket for Terraform State:

    Ensure you have an S3 bucket named shush-terraform-state to store your Terraform state files. This centralized storage maintains the state of your infrastructure. If you prefer a different bucket name, update the provider.tf file to reflect the new bucket name.

     
    ### Configure the Backend in provider.tf:

    In each service's provider.tf file, set up the backend configuration to point to your S3 bucket. This ensures Terraform uses the specified bucket for state management. Here's an example configuration:
    
    ### Configure the Backend in terraform.tfvars:

    Edit the `terraform.tfvars` file to customize variables specific to AWS api gateway deployment. This file allows you to define values for variables used in your Terraform configuration, tailoring the deployment to your requirements.

    1. sherlock_base_url value is sherlock cluster endpoint 
    2. sherlock_api_client : name of the test client to generate client id ans secret 
    3. stage_name : stage name

    Initialize and apply the Terraform configuration:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```
## **Step 2: Oauth 2 Token**
1. **Oauth Token**

    ### Oauth Token:
   The terraform output:
    api_endpoint = "https://ufkie51rq7.execute-api.us-west-1.amazonaws.com/dev"
    cognito_app_client_id = "45u19rik5355ofd7pi7vkv49ug"
    cognito_app_client_secret = <sensitive>
    cognito_user_pool_endpoint = "https://sherlockapi.auth.us-west-1.amazoncognito.com"

    cognito_app_client_secret is sensitive value, run the below command to get the cognito_app_client_secret value

    ```bash
    terraform output cognito_app_client_secret
    ```

    below is the sample curl to get oauth token, replace  api replace, cognito_app_client_id, cognito_app_client_secret

    make an api call to get the Oauth Bearer token:
    ```bash
        curl --location 'https://{cognito_user_pool_endpoint}/oauth2/token' \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --header 'Cookie: XSRF-TOKEN=b0c9bb12-e74b-4746-972d-2ea37ece1b52' \
        --data-urlencode 'grant_type=client_credentials' \
        --data-urlencode 'client_id={cognito_app_client_id}' \
        --data-urlencode 'client_secret={cognito_app_client_secret}' \
        --data-urlencode 'scope=sherlockapiresource/write'
    ```
    copy the "access_token" value, sample output

    ```bash
    {
        "access_token": "eyJraWQiOiJHUmhkU0dCU3lEN2lrSXJGdW9ZU2ZCOW84WlN4S0xoeTFLYmU5dUhQVCtnPSIsImFsZyI6IlJTMjU2In0.eyJzdWIiOiI0NXUxOXJpazUzNTVvZmQ3cGk3dmt2NDl1ZyIsInRva2VuX3VzZSI6ImFjY2VzcyIsInNjb3BlIjoic2hlcmxvY2thcGlyZXNvdXJjZVwvd3JpdGUiLCJhdXRoX3RpbWUiOjE3MzYxOTIyNzgsImlzcyI6Imh0dHBzOlwvXC9jb2duaXRvLWlkcC51cy13ZXN0LTEuYW1hem9uYXdzLmNvbVwvdXMtd2VzdC0xX2xpQTZZczd5cyIsImV4cCI6MTczNjE5NTg3OCwiaWF0IjoxNzM2MTkyMjc4LCJ2ZXJzaW9uIjoyLCJqdGkiOiIyYzY1ZTg3NS0xODYyLTQ5NWMtYjM5Ni1jNzZiODI5MjhiZDAiLCJjbGllbnRfaWQiOiI0NXUxOXJpazUzNTVvZmQ3cGk3dmt2NDl1ZyJ9.oQTPgp8_TGU0TQSGIO0xPOyZ2Ri6t8kYEMTnIreIgNCET5vAkm85f05diBgQLDBXj6Gri6ZY5qAXLZ2LnE-k0eEiOQNlprvnU4vwL5WT2GKieEX5oX5l76_yOClO1pNQcuSppjo7QDYcRCq0NntL1Ig0uwD6NGaHCOVu-qxv8KFLLtA7yVznORwmtjrumAeYAK_NUQHrWeh5LOh7ajExjl9Bed2sr61NGvNu7qfZe5ejnbxcf39wnPj5CL3qIP_eAMPzpKy8dCS_UjVY_Gi6Fy6ds5xYIWHfISFnCe9OTi4rNueyc-hEE9luRZC8W7Aerj-g3yuDYShhjbadq_6f6w",
        "expires_in": 3600,
        "token_type": "Bearer"
        }   
    ```
## **Step 3: Shush API Resource **
1. **Shush  Resource API call**
    Below is the same Shush resource API call:

    replace api_endpoint,access_token values 
    
    ```bash
        curl --location 'https://{api_endpoint}/account-status-change/v0/retrieve-bundle' \
        --header 'Authorization: Bearer {access_token}' \
        --header 'Content-Type: application/json' \
        --data '{
        "msisdn": "+18184823381",
        "identifier": "string",
        "carrierName": "string",
        "customerName": "string"
        }'
    ```