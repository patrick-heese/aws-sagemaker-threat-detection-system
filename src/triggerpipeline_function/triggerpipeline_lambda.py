import json
import boto3
import os  

PIPELINE_NAME = os.environ.get("PIPELINE_NAME", "simple-cybersecurity-pipeline")

def lambda_handler(event, context):
# Initialize SageMaker client
    sagemaker_client = boto3.client("sagemaker")
    
    try:
# Start your pipeline
        response = sagemaker_client.start_pipeline_execution(
            PipelineName=PIPELINE_NAME
        )
        
        print(f"Pipeline started: {response['PipelineExecutionArn']}")
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Pipeline execution started successfully",
                "executionArn": response['PipelineExecutionArn']
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error starting pipeline: {str(e)}")
        }
