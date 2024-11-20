import boto3
import os

def lambda_handler(event, context):
    account_id = event['detail']['serviceEventDetails']['createManagedAccountStatus']['account']['accountId']
    print(f"Attaching permission set to Account ID: {account_id}")

    client = boto3.client('sso-admin')

    try:
        response = client.create_account_assignment(
            InstanceArn=os.environ['IDENTITY_CENTER_ARN'],
            PermissionSetArn=os.environ['PERMISSION_SET'],
            PrincipalId=os.environ['PRINCIPAL_ID'],
            PrincipalType=os.environ['PRINCIPAL_TYPE'],
            TargetId=account_id,
            TargetType=os.environ['TARGET_TYPE']
        )
        print("Permission set attached successfully:", response)
    except Exception as e:
        print(f"Failed to attach permission set: {e}")
