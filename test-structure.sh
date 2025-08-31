#!/bin/bash
#
# Test script to create Terragrunt directory structure using the new module system
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details
#
# Creates: envs/testing with env.hcl, projects/helloworld with project.hcl
# Creates: envs/testing/us-west-2 with region.hcl, zones, and resources

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="$(pwd)"

echo -e "${BLUE}Creating Terragrunt test structure using new module system...${NC}"

# 1. Create environment using manage.pl
echo -e "${CYAN}Creating environment: testing${NC}"
./manage.pl add env testing --force

echo -e "  ✓ Environment 'testing' created with env.hcl"


# 2. Create project using manage.pl
echo -e "${CYAN}Creating project: helloworld${NC}"
./manage.pl add project helloworld --force

echo -e "  ✓ Project 'helloworld' created with project.hcl"


# 3. Create region using manage.pl
echo -e "${CYAN}Creating region: us-west-2${NC}"
./manage.pl add region us-west-2 -e testing --force

echo -e "  ✓ Region 'us-west-2' created with region.hcl"

# 4. Create zones using manage.pl
echo -e "${CYAN}Creating zones: us-west-2a, us-west-2b, us-west-2c${NC}"
./manage.pl add zone us-west-2a -e testing -r us-west-2 --force
./manage.pl add zone us-west-2b -e testing -r us-west-2 --force  
./manage.pl add zone us-west-2c -e testing -r us-west-2 --force
echo -e "  ✓ Zones created with zone.hcl files"

# 5. Create resources using manage.pl
echo -e "${CYAN}Creating VPC resource${NC}"
./manage.pl add resource vpc -e testing -r us-west-2 --force
echo -e "  ✓ VPC resource created"

echo -e "${CYAN}Creating EKS cluster resource${NC}"
./manage.pl add resource eks -e testing -r us-west-2 --force
echo -e "  ✓ EKS cluster resource created"

# Create zone-specific EKS node groups
echo -e "${CYAN}Creating EKS node groups in zones${NC}"
./manage.pl add resource eks-nodes -e testing -r us-west-2 -z us-west-2a --force
./manage.pl add resource eks-nodes -e testing -r us-west-2 -z us-west-2b --force
./manage.pl add resource eks-nodes -e testing -r us-west-2 -z us-west-2c --force
echo -e "  ✓ EKS node groups created in all zones"

# 6. Create some example environment-level resources
echo -e "${CYAN}Creating environment-level IAM resources${NC}"
./manage.pl add resource iam-roles -e testing --force
echo -e "  ✓ Environment-level IAM roles created"




# 7. Display the created structure
echo -e "\n${BLUE}=== Created Structure Using Module System ===${NC}"
tree -L 5 envs projects 2>/dev/null || {
  echo "Structure created using manage.pl module system:"
  echo "  - envs/testing/ (with env.hcl)"
  echo "  - projects/helloworld/ (with project.hcl)"  
  echo "  - envs/testing/us-west-2/ (with region.hcl)"
  echo "  - envs/testing/us-west-2/{us-west-2a,us-west-2b,us-west-2c}/ (with zone.hcl)"
  echo "  - Resources: vpc, eks, eks-nodes, iam-roles"
}

echo -e "\n${GREEN}✓ Test structure created successfully using the new module system!${NC}"
echo -e "${YELLOW}Features demonstrated:${NC}"
echo -e "  - Module-based infrastructure creation (env, project, region, zone)"
echo -e "  - Template-generated configuration files (.hcl)"
echo -e "  - Resource placement at different hierarchy levels"
echo -e "  - Automatic validation and standardized naming"
echo -e "${YELLOW}\nNext steps:${NC}"
echo -e "  - Run 'terragrunt plan' in any resource directory"
echo -e "  - Update terraform sources in resource templates as needed"
echo -e "  - Add more resources using: ./manage.pl add resource <name> <options>"