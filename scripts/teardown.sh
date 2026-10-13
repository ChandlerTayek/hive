#!/usr/bin/env bash
# Destroy the hive stack, then list anything still billing.
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
cd "$(dirname "$0")/../terraform"

if [ -f main.tf ]; then
  terraform destroy -auto-approve
else
  echo "No Terraform yet; skipping destroy."
fi

echo "Checking $REGION for leftovers (all lists should be empty):"
echo "EKS clusters:";      aws eks list-clusters --region "$REGION" --query 'clusters' --output text
echo "NAT gateways:";      aws ec2 describe-nat-gateways --region "$REGION" \
  --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId' --output text
echo "Load balancers:";    aws elbv2 describe-load-balancers --region "$REGION" \
  --query 'LoadBalancers[].LoadBalancerName' --output text
echo "Unattached EBS:";    aws ec2 describe-volumes --region "$REGION" \
  --filters Name=status,Values=available --query 'Volumes[].VolumeId' --output text
echo "Running instances:"; aws ec2 describe-instances --region "$REGION" \
  --filters Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId' --output text
