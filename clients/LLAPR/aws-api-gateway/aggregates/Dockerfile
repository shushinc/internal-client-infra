# Use an official AWS Lambda base image
FROM public.ecr.aws/lambda/python:3.8

# Set the working directory in the container
WORKDIR /var/task

# Copy the script, requirements file, and any other necessary files
COPY aggregate.py .
COPY config.json .
COPY portal_api_config.cfg .
COPY api_pricing.csv .
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Set the entrypoint for the Lambda function
CMD ["aggregate.lambda_handler"]
