import boto3
import os

def lambda_handler(event, context):    
    # Initialize the boto3 client for identity store
    client = boto3.client('identitystore')
    
    # Environment variables
    CONTROL_TOWER_ADMIN_GROUP_ID = os.environ['CONTROL_TOWER_ADMIN_GROUP_ID']
    IDENTITY_CENTER_ID = os.environ['IDENTITY_CENTER_ID']
    
    # Parse the event to extract GroupId and UserId
    group_id = event.get('detail', {}).get('requestParameters', {}).get('groupId')
    user_id = event.get('detail', {}).get('requestParameters', {}).get('member', {}).get('memberId')
    
    # Extract the role from the event
    user_role = event.get('detail', {}).get('userIdentity', {}).get('sessionContext', {}).get('sessionIssuer', {}).get('userName', '')

    # Check if the user role contains 'AWSReservedSSO_AWSAdministratorAccess'
    if 'AWSReservedSSO_AWSAdministratorAccess' in user_role:
        print(f'User role {user_role} contains AWSReservedSSO_AWSAdministratorAccess. No action taken.')
        return {
            'status': 'No action taken',
            'reason': 'User role contains AWSReservedSSO_AWSAdministratorAccess',
            'user_role': user_role,
            'group_id': group_id,
            'user_id': user_id
        }
    
    # If the group ID matches the CONTROL_TOWER_ADMIN_GROUP_ID, proceed with deletion
    if group_id == CONTROL_TOWER_ADMIN_GROUP_ID:
        # Get the membership ID
        response = client.get_group_membership_id(
            IdentityStoreId=IDENTITY_CENTER_ID,
            GroupId=group_id,
            MemberId={
                'UserId': user_id
            }
        )
        
        membership_id = response.get('MembershipId')
        
        # Delete the group membership
        delete_response = client.delete_group_membership(
            IdentityStoreId=IDENTITY_CENTER_ID,
            MembershipId=membership_id
        )
        
        print(f'Membership ID {membership_id} for user {user_id} deleted from group {group_id}.')
        return delete_response
    else:
        print(f'Group ID {group_id} does not match CONTROL_TOWER_ADMIN_GROUP_ID.')
        return {
            'status': 'No action taken',
            'group_id': group_id,
            'user_id': user_id
        }
