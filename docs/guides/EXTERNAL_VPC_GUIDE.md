# External VPC Configuration Guide

## Overview

When you have existing VPCs, subnets, and CIDR blocks that are managed outside of your Terragrunt setup (by another team, pre-existing infrastructure, or different tools), you can use the `external-vpc` resource type to reference them in your Terragrunt configurations.

## How It Works

### External VPC Resource

The `external-vpc` resource type creates a Terraform module that:
- **Validates** external VPC and subnet IDs exist and are accessible
- **Outputs** VPC information in the same format as managed VPCs
- **Provides** consistent interface for other resources to reference

### Two Configuration Methods

**Method 1: JSON Configuration File (Recommended)**
```bash
# Create external VPC resource
./manage.pl add resource "client-vpc:external-vpc" -e production -r us-east-1

# Configure VPC details in JSON file
cp envs/production/web-app/us-east-1/client-vpc/vpc-config.example.json \
   envs/production/web-app/us-east-1/client-vpc/vpc-config.json

# Edit vpc-config.json with actual values
```

**Method 2: Direct Terragrunt Configuration**
- Edit the `terragrunt.hcl` file directly
- Replace placeholder values with actual IDs and CIDRs

## Usage Examples

### Step 1: Create External VPC Resource

```bash
# For production environment
./manage.pl add resource "prod-vpc:external-vpc" -e production -p web-app -r us-east-1

# For staging environment  
./manage.pl add resource "staging-vpc:external-vpc" -e staging -p api-server -r us-west-2

# For shared services
./manage.pl add resource "shared-network:external-vpc" -e shared -p infrastructure -r us-east-1
```

### Step 2: Configure VPC Details

Create `vpc-config.json` with your actual values:

```json
{
  "vpc_id": "vpc-0a1b2c3d4e5f6g7h8",
  "vpc_cidr": "10.10.0.0/16",
  
  "private_subnet_ids": [
    "subnet-0123456789abcdef0",
    "subnet-0123456789abcdef1",
    "subnet-0123456789abcdef2"
  ],
  
  "public_subnet_ids": [
    "subnet-0987654321fedcba0",
    "subnet-0987654321fedcba1",
    "subnet-0987654321fedcba2"
  ],
  
  "database_subnet_ids": [
    "subnet-0555666777888999a",
    "subnet-0555666777888999b",
    "subnet-0555666777888999c"
  ],
  
  "private_subnet_cidrs": [
    "10.10.1.0/24",
    "10.10.2.0/24",
    "10.10.3.0/24"
  ],
  
  "public_subnet_cidrs": [
    "10.10.101.0/24",
    "10.10.102.0/24",
    "10.10.103.0/24"
  ],
  
  "availability_zones": [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c"
  ]
}
```

### Step 3: Reference External VPC in Other Resources

Now your databases, load balancers, and other resources can reference the external VPC:

```hcl
# In envs/production/web-app/us-east-1/database/terragrunt.hcl
dependency "external_vpc" {
  config_path = "../prod-vpc"
}

inputs = {
  # Use external VPC subnets
  vpc_id = dependency.external_vpc.outputs.vpc_id
  subnet_ids = dependency.external_vpc.outputs.database_subnets
  
  # Other database configuration...
}
```

## Real-World Scenarios

### Scenario 1: Client-Provided VPC

Your client provides an existing VPC with specific subnets:

```bash
# Create external VPC reference
./manage.pl add resource "client-network:external-vpc" -e production -p client-app -r us-west-2

# Configure with client's actual values
# Client provides: VPC vpc-client123, subnets subnet-web1, subnet-web2, subnet-db1, subnet-db2
```

**Directory Structure:**
```
envs/production/client-app/us-west-2/
├── client-network/           # External VPC definition
│   ├── terragrunt.hcl
│   └── vpc-config.json      # Client's VPC details
├── database/                # RDS using client VPC
│   └── terragrunt.hcl       # References ../client-network
└── web-servers/             # EC2 using client VPC
    └── terragrunt.hcl       # References ../client-network
```

### Scenario 2: Multi-Team Environment

Network team manages VPCs, your team manages applications:

```bash
# Reference network team's VPC
./manage.pl add resource "netteam-vpc:external-vpc" -e shared -p infrastructure -r us-east-1

# Your application resources reference it
./manage.pl add resource "app-db:rds-mysql" -e production -p my-app -r us-east-1
./manage.pl add resource "app-cache:redis" -e production -p my-app -r us-east-1
```

### Scenario 3: Migration from Existing Infrastructure

Gradually migrate resources to Terragrunt while keeping existing VPC:

```bash
# Step 1: Define existing VPC
./manage.pl add resource "legacy-vpc:external-vpc" -e production -p migration -r us-west-2

# Step 2: Create new resources that use existing VPC
./manage.pl add resource "new-rds:rds-postgres" -e production -p migration -r us-west-2
./manage.pl add resource "new-cache:redis" -e production -p migration -r us-west-2

# Step 3: Later migrate VPC to Terragrunt management
./manage.pl add resource "managed-vpc:vpc" -e production -p migration -r us-west-2
# Update dependencies from external-vpc to managed-vpc
```

## Resource Template Integration

All resource templates now support both managed and external VPCs:

### RDS Example
```hcl
# Option 1: Managed VPC
dependency "vpc" {
  config_path = "../vpc"
}

# Option 2: External VPC
dependency "external_vpc" {
  config_path = "../client-vpc"
}

inputs = {
  # Works with both:
  vpc_id = dependency.external_vpc.outputs.vpc_id  # or dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.external_vpc.outputs.database_subnets
}
```

### EKS Example
```hcl
dependency "external_vpc" {
  config_path = "../company-vpc"
}

inputs = {
  vpc_id = dependency.external_vpc.outputs.vpc_id
  subnet_ids = dependency.external_vpc.outputs.private_subnets
  
  # EKS can also use public subnets for load balancers
  public_subnet_ids = dependency.external_vpc.outputs.public_subnets
}
```

## Configuration Options

### Required Fields
- `vpc_id`: The VPC ID (vpc-xxxxxxxxx)
- `private_subnet_ids`: List of private subnet IDs
- `public_subnet_ids`: List of public subnet IDs

### Optional Fields
- `database_subnet_ids`: Database-specific subnets
- `vpc_cidr`: VPC CIDR block (for validation)
- `private_subnet_cidrs`: Private subnet CIDRs
- `public_subnet_cidrs`: Public subnet CIDRs  
- `availability_zones`: AZ list
- `internet_gateway_id`: IGW ID
- `nat_gateway_ids`: NAT gateway IDs
- `route_table_ids`: Route table IDs

### Placeholder Values

The template includes placeholder values that need replacement:
- `REPLACE_WITH_ACTUAL_VPC_ID`
- `REPLACE_WITH_PRIVATE_SUBNET_1`
- `REPLACE_WITH_VPC_CIDR`

These act as reminders of what needs to be configured.

## Validation and Safety

### Automatic Validation
- VPC ID format validation
- Subnet ID format validation  
- VPC existence check via AWS API
- CIDR block matching (if provided)
- Subnet-to-VPC relationship validation

### Error Handling
```bash
# Common errors and solutions:

# Error: VPC not found
# Solution: Verify VPC ID and AWS permissions

# Error: Subnet not in VPC
# Solution: Check subnet IDs belong to the specified VPC

# Error: CIDR mismatch  
# Solution: Update vpc-config.json with correct CIDR blocks
```

## Benefits

✅ **Flexibility** - Use existing VPCs without recreating them  
✅ **Team Independence** - Network team manages VPCs, app team manages resources  
✅ **Migration Path** - Gradual migration from existing to Terragrunt-managed infrastructure  
✅ **Validation** - Automatic checks ensure VPC resources are valid and accessible  
✅ **Compatibility** - Same interface as managed VPCs for seamless integration  
✅ **Documentation** - Clear configuration files document network dependencies  

## Best Practices

### 1. Use JSON Configuration Files
- Easier to maintain than inline Terragrunt configuration
- Can be version controlled separately if needed
- Clear documentation of external dependencies

### 2. Document External Dependencies
- Include contact information for VPC owners
- Document any constraints or requirements
- Note planned migration paths (if applicable)

### 3. Validate Configuration
- Always run `terragrunt plan` before `apply`
- Test connectivity from resources to external subnets
- Verify security group rules allow required traffic

### 4. Environment Consistency
- Use same VPC configuration pattern across environments
- Maintain similar subnet layouts when possible
- Document differences between environments

## Troubleshooting

### VPC Configuration Issues
```bash
# Test VPC accessibility
aws ec2 describe-vpcs --vpc-ids vpc-0123456789abcdef0

# Verify subnets
aws ec2 describe-subnets --subnet-ids subnet-0123456789abcdef0

# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0123456789abcdef0"
```

### Terragrunt Issues
```bash
# Validate configuration
cd envs/production/web-app/us-east-1/client-vpc
terragrunt validate

# Plan to see what would be created
terragrunt plan

# Check outputs
terragrunt output
```

This system provides a complete solution for integrating external VPCs into your Terragrunt workflow while maintaining consistency and validation!