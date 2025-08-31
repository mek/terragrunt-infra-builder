#!/bin/bash
#
# Test Infrastructure Setup Script
# This script creates a complete test environment with EKS cluster and associated resources
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details
#
# Environment: testme
# Project: h2g2
# Region: eu-west-1
# Components: IAM roles, Security Group, EKS Cluster

set -e  # Exit on any error

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
ENV="testme"
PROJECT="h2g2" 
REGION="eu-west-1"
CLUSTER_NAME="be-cool"
AVAILABILITY_ZONES=("a" "b" "c")

echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}Infrastructure Test Setup Script${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo -e "  Environment: ${ENV}"
echo -e "  Project: ${PROJECT}"
echo -e "  Region: ${REGION}"
echo -e "  Cluster: ${CLUSTER_NAME}"
echo -e "  Availability Zones: ${REGION}a, ${REGION}b, ${REGION}c"
echo ""

# Function to run manage.pl commands with error handling
run_manage_command() {
    local description=$1
    local command=$2
    
    echo -e "${YELLOW}${description}${NC}"
    echo -e "${BLUE}Command: ${command}${NC}"
    
    if eval "$command"; then
        echo -e "${GREEN}✓ Success${NC}"
        echo ""
    else
        echo -e "${RED}✗ Failed: ${description}${NC}"
        echo -e "${RED}Command: ${command}${NC}"
        exit 1
    fi
}

echo -e "${GREEN}Step 1: Creating External Infrastructure${NC}"
echo "=========================================="

# Create external VPC configuration (environment level)
run_manage_command \
    "Creating external VPC configuration" \
    "./manage.pl add resource \"client-vpc:external-vpc\" -e ${ENV}"

# Create external S3 backend configuration (environment level)
run_manage_command \
    "Creating external S3 backend configuration" \
    "./manage.pl add resource \"company-backend:external-s3-backend\" -e ${ENV}"

echo -e "${GREEN}Step 2: Creating IAM Roles${NC}"
echo "=========================================="

# Create EKS cluster service role
run_manage_command \
    "Creating EKS cluster service role" \
    "./manage.pl add resource \"eks-cluster-role:iam-role\" -e ${ENV} -p ${PROJECT}"

# Create EKS node group role  
run_manage_command \
    "Creating EKS node group role" \
    "./manage.pl add resource \"eks-node-role:iam-role\" -e ${ENV} -p ${PROJECT}"

# Create EKS pod execution role
run_manage_command \
    "Creating EKS pod execution role" \
    "./manage.pl add resource \"eks-pod-role:iam-role\" -e ${ENV} -p ${PROJECT}"

echo -e "${GREEN}Step 3: Creating Region Structure${NC}"
echo "=========================================="

# Create region directory structure
run_manage_command \
    "Creating ${REGION} region" \
    "./manage.pl add region ${REGION} -e ${ENV} -p ${PROJECT}"

# Create availability zones
for zone in "${AVAILABILITY_ZONES[@]}"; do
    run_manage_command \
        "Creating availability zone ${REGION}${zone}" \
        "./manage.pl add zone ${REGION}${zone} -e ${ENV} -p ${PROJECT} -r ${REGION}"
done

echo -e "${GREEN}Step 4: Creating Security Group${NC}"
echo "=========================================="

# Create EKS cluster security group
run_manage_command \
    "Creating EKS cluster security group" \
    "./manage.pl add resource \"eks-cluster-security-group:security-group\" -e ${ENV} -p ${PROJECT} -r ${REGION}"

echo -e "${GREEN}Step 5: Creating EKS Cluster${NC}"
echo "=========================================="

# Create EKS cluster
run_manage_command \
    "Creating EKS cluster '${CLUSTER_NAME}'" \
    "./manage.pl add resource \"${CLUSTER_NAME}:eks\" -e ${ENV} -p ${PROJECT} -r ${REGION}"

echo -e "${GREEN}Step 6: Verification${NC}"
echo "=========================================="

echo -e "${BLUE}Checking created directory structure:${NC}"

# Check if all expected directories were created
EXPECTED_DIRS=(
    "envs/${ENV}/client-vpc"
    "envs/${ENV}/company-backend"
    "envs/${ENV}/${PROJECT}/eks-cluster-role"
    "envs/${ENV}/${PROJECT}/eks-node-role" 
    "envs/${ENV}/${PROJECT}/eks-pod-role"
    "envs/${ENV}/${PROJECT}/${REGION}"
    "envs/${ENV}/${PROJECT}/${REGION}/${REGION}a"
    "envs/${ENV}/${PROJECT}/${REGION}/${REGION}b"
    "envs/${ENV}/${PROJECT}/${REGION}/${REGION}c"
    "envs/${ENV}/${PROJECT}/${REGION}/eks-cluster-security-group"
    "envs/${ENV}/${PROJECT}/${REGION}/${CLUSTER_NAME}"
)

echo ""
for dir in "${EXPECTED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $dir"
    else
        echo -e "  ${RED}✗${NC} $dir (missing)"
    fi
done

echo ""
echo -e "${BLUE}Listing complete directory structure:${NC}"
if [ -d "envs/${ENV}/${PROJECT}" ]; then
    tree "envs/${ENV}/${PROJECT}" 2>/dev/null || find "envs/${ENV}/${PROJECT}" -type d | sort
else
    echo -e "${RED}Project directory not found!${NC}"
fi

echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}Infrastructure Setup Complete!${NC}"  
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Review the generated terragrunt.hcl files"
echo "2. Customize IAM role policies and EKS cluster configuration"
echo "3. Run terraform-module-analyzer to generate inputs.json files:"
echo -e "   ${YELLOW}./admin/terraform-module-analyzer.pl${NC}"
echo "4. Deploy resources using terragrunt-deploy.pl:"
echo -e "   ${YELLOW}./terragrunt-deploy.pl -d envs/${ENV}/${PROJECT}${NC}"
echo ""
echo -e "${BLUE}Created Resources:${NC}"
echo "• External Infrastructure: client-vpc (external VPC), company-backend (external S3 backend)"
echo "• IAM Roles: eks-cluster-role, eks-node-role, eks-pod-role"
echo "• Region: ${REGION} with zones ${REGION}a, ${REGION}b, ${REGION}c"
echo "• Security Group: eks-cluster-security-group"
echo "• EKS Cluster: ${CLUSTER_NAME}"
echo ""
echo -e "${YELLOW}Important Configuration Steps:${NC}"
echo "1. Configure external VPC details in: envs/${ENV}/client-vpc/vpc-config.json"
echo "2. Configure external backend details in: envs/${ENV}/company-backend/backend-config.json"
echo "3. Remember to configure dependencies between resources in their terragrunt.hcl files"
echo ""
echo -e "${BLUE}External Configuration Files:${NC}"
echo "• Copy vpc-config.example.json to vpc-config.json in client-vpc directory"
echo "• Copy backend-config.example.json to backend-config.json in company-backend directory"
echo "• Fill in actual VPC IDs, subnet IDs, S3 bucket name, and DynamoDB table name"
