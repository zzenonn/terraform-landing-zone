#!/bin/bash

export AWS_PAGER=""

# Function to delete stack instances with additive backoff
delete_stack_instances_with_retry() {
  local stackset_name=$1
  local region=$2
  local ou_id=$3
  local account=$4
  local max_attempts=5
  local attempt=1
  local delay=30

  while [ $attempt -le $max_attempts ]; do
    echo "Attempting to delete stack instances for stackset: $stackset_name (Attempt $attempt/$max_attempts)"

    if [ -n "$ou_id" ]; then
      if aws cloudformation delete-stack-instances --stack-set-name "$stackset_name" --deployment-targets OrganizationalUnitIds=$ou_id --regions "$region" --no-retain-stacks --no-paginate; then
        echo "Successfully deleted stack instances for OU: $ou_id in region: $region"
        return 0
      fi
    else
      if aws cloudformation delete-stack-instances --stack-set-name "$stackset_name" --regions "$region" --accounts "$account" --no-retain-stacks --no-paginate; then
        echo "Successfully deleted stack instances for account: $account in region: $region"
        return 0
      fi
    fi

    echo "Failed to delete stack instances for stackset: $stackset_name. Retrying in $delay seconds..."
    sleep $delay
    attempt=$((attempt + 1))
    delay=$((30 * attempt)) # Additive backoff
  done

  echo "Failed to delete stack instances for stackset: $stackset_name after $max_attempts attempts."
  return 1
}

# Function to delete all instances in a stackset
delete_stackset_instances() {
  local stackset_name=$1

  echo "Deleting instances of stackset: $stackset_name"

  permission_model=$(aws cloudformation describe-stack-set --stack-set-name "$stackset_name" --query 'StackSet.PermissionModel' --output text)

  if [ "$permission_model" == "SERVICE_MANAGED" ]; then
    instances=$(aws cloudformation list-stack-instances --stack-set-name "$stackset_name" --query 'Summaries[*].[Region, OrganizationalUnitId]' --output text)
    
    if [ -n "$instances" ]; then
      while read -r region ou_id; do
        delete_stack_instances_with_retry "$stackset_name" "$region" "$ou_id" ""
      done <<< "$instances"
    else
      echo "No Organizational Unit IDs found for stackset: $stackset_name"
    fi

  else
    instances=$(aws cloudformation list-stack-instances --stack-set-name "$stackset_name" --query 'Summaries[*].[Region, Account]' --output text)

    if [ -n "$instances" ]; then
      while read -r region account; do
        delete_stack_instances_with_retry "$stackset_name" "$region" "" "$account"
      done <<< "$instances"
    else
      echo "No instances found for stackset: $stackset_name"
    fi
  fi
}

# Function to delete a stack set with exponential backoff
delete_stackset_with_retry() {
  local stackset_name=$1
  local max_attempts=5
  local attempt=1
  local delay=30

  while [ $attempt -le $max_attempts ]; do
    echo "Attempting to delete stackset: $stackset_name (Attempt $attempt/$max_attempts)"
    if aws cloudformation delete-stack-set --stack-set-name "$stackset_name" --no-paginate; then
      echo "Successfully deleted stackset: $stackset_name"
      return 0
    else
      echo "Failed to delete stackset: $stackset_name. Retrying in $delay seconds..."
      sleep $delay
      attempt=$((attempt + 1))
      delay=$((30 * attempt)) # Additive backoff
    fi
  done

  echo "Failed to delete stackset: $stackset_name after $max_attempts attempts."
  return 1
}

# Delete CloudFormation Stacks
echo "Deleting CloudFormation stacks that begin with 'AWSControlTower'..."
for stack in $(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?starts_with(StackName, 'AWSControlTower')].StackName" --output text); do
  echo "Deleting stack: $stack"
  aws cloudformation delete-stack --stack-name "$stack" --no-paginate
  aws cloudformation wait stack-delete-complete --stack-name "$stack" --no-paginate
  echo "Deleted stack: $stack"
done

# Delete CloudFormation StackSets and their instances (excluding AWSControlTowerExecutionRole)
echo "Deleting CloudFormation stacksets and their instances that begin with 'AWSControlTower' (excluding AWSControlTowerExecutionRole)..."
for stackset in $(aws cloudformation list-stack-sets --status ACTIVE --query "Summaries[?starts_with(StackSetName, 'AWSControlTower') && StackSetName != 'AWSControlTowerExecutionRole'].StackSetName" --output text); do
  # Delete instances within the stackset
  delete_stackset_instances "$stackset"

  # Delete the stackset itself with retry and exponential backoff
  delete_stackset_with_retry "$stackset"
done

# Delete AWSControlTowerExecutionRole StackSet last
echo "Deleting AWSControlTowerExecutionRole stackset and its instances last..."
delete_stackset_instances "AWSControlTowerExecutionRole"
delete_stackset_with_retry "AWSControlTowerExecutionRole"

echo "All specified CloudFormation stacks, stack instances, and stacksets have been deleted."
