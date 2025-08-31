# External S3 Backend Configuration Guide

## Overview

When your Terraform state S3 bucket and DynamoDB lock table are managed outside of your Terragrunt setup (by another team, existing infrastructure, or different tools), you can use the `external-s3-backend` resource type to reference them. The root terragrunt.hcl will automatically detect and use these external backends.

## How It Works

### External S3 Backend Resource

The `external-s3-backend` resource type creates a Terraform module that:
- **Validates** external S3 bucket and DynamoDB table exist and are accessible
- **Provides** backend configuration to root terragrunt.hcl automatically  
- **Supports** KMS encryption, cross-region backends, and custom state key prefixes
- **Ensures** proper configuration for Terraform state management

### Automatic Detection

The enhanced root terragrunt.hcl automatically:
1. **Searches** for external backend configurations in the environment/project hierarchy
2. **Uses** external backend settings if found and configured
3. **Falls back** to smart generated defaults if no external backend is configured
4. **Supports** KMS encryption, custom regions, and state key prefixes

## Usage Examples

### Step 1: Create External S3 Backend Resource

```bash
# For production environment
./manage.pl add resource "prod-backend:external-s3-backend" -e production -p web-app -r us-east-1

# For staging environment  
./manage.pl add resource "staging-backend:external-s3-backend" -e staging -p api-server -r us-west-2

# For shared services
./manage.pl add resource "shared-backend:external-s3-backend" -e shared -p infrastructure -r us-east-1
```

### Step 2: Configure Backend Details

Create `backend-config.json` with your actual backend information:

```json
{
  "s3_bucket_name": "my-company-terraform-state",
  "s3_bucket_region": "us-east-1",
  
  "dynamodb_table_name": "my-company-terraform-locks",
  "dynamodb_table_region": "us-east-1",
  
  "kms_key_id": "alias/terraform-state-key",
  "state_key_prefix": "environments/",
  
  "validate_bucket_versioning": true,
  "validate_bucket_encryption": true,
  "validate_dynamodb_table": true
}
```

### Step 3: All Resources Automatically Use External Backend

Once configured, **all** resources in that environment/project automatically use the external backend - no additional configuration needed!

```hcl
# Any resource in envs/production/web-app/ will automatically use:
# - S3 bucket: my-company-terraform-state
# - DynamoDB table: my-company-terraform-locks
# - KMS key: alias/terraform-state-key
# - State keys: environments/envs/production/web-app/.../terraform.tfstate
```

## Real-World Scenarios

### Scenario 1: Company-Wide Shared Backend

Your DevOps team manages a central S3 bucket and DynamoDB table for all Terraform state:

```bash
# Create external backend reference
./manage.pl add resource "company-backend:external-s3-backend" -e production -p my-app -r us-east-1
```

**Backend Configuration:**
```json
{
  "s3_bucket_name": "acme-corp-terraform-state",
  "s3_bucket_region": "us-east-1",
  "dynamodb_table_name": "acme-corp-terraform-locks",
  "dynamodb_table_region": "us-east-1",
  "kms_key_id": "alias/acme-terraform-encryption",
  "state_key_prefix": "teams/my-team/"
}
```

**Result:** All resources in `envs/production/my-app/` use the company backend automatically.

### Scenario 2: Client-Provided Backend

Your client provides their own AWS account with existing state management:

```bash
# Reference client's backend infrastructure
./manage.pl add resource "client-backend:external-s3-backend" -e production -p client-project -r us-west-2
```

**Directory Structure:**
```
envs/production/client-project/us-west-2/
├── client-backend/              # External backend definition
│   ├── terragrunt.hcl
│   └── backend-config.json     # Client's backend details
├── database/                   # Uses client backend automatically
├── web-servers/               # Uses client backend automatically  
└── load-balancer/            # Uses client backend automatically
```

### Scenario 3: Cross-Region Backend

S3 bucket in one region, DynamoDB table in another:

```json
{
  "s3_bucket_name": "global-terraform-state",
  "s3_bucket_region": "us-west-2",
  "dynamodb_table_name": "terraform-locks-east",
  "dynamodb_table_region": "us-east-1"
}
```

### Scenario 4: Environment Isolation with External Backends

Separate backends for different environments, all managed externally:

```bash
# Production backend
./manage.pl add resource "prod-backend:external-s3-backend" -e production -p myapp -r us-east-1

# Staging backend  
./manage.pl add resource "staging-backend:external-s3-backend" -e staging -p myapp -r us-east-1

# Development backend
./manage.pl add resource "dev-backend:external-s3-backend" -e development -p myapp -r us-east-1
```

## Configuration Options

### Required Fields
- `s3_bucket_name`: The S3 bucket name for state storage
- `dynamodb_table_name`: The DynamoDB table name for state locking

### Optional Fields
- `s3_bucket_region`: S3 bucket region (defaults to current region)
- `dynamodb_table_region`: DynamoDB table region (defaults to current region)
- `kms_key_id`: KMS key for S3 encryption (supports ARN, alias, or key ID)
- `state_key_prefix`: Prefix for state keys in the bucket
- `validate_bucket_versioning`: Validate versioning is enabled (default: true)
- `validate_bucket_encryption`: Validate encryption is enabled (default: true)  
- `validate_dynamodb_table`: Validate table exists and is accessible (default: true)

### Advanced Configuration Examples

**KMS Key Formats:**
```json
{
  "kms_key_id": "alias/my-terraform-key"
}
// or
{
  "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
}
// or
{
  "kms_key_id": "12345678-1234-1234-1234-123456789012"
}
```

**Custom State Key Prefix:**
```json
{
  "state_key_prefix": "team-alpha/",
  "s3_bucket_name": "shared-terraform-state"
}
```
Result: State keys like `team-alpha/envs/production/web-app/database/terraform.tfstate`

**Validation Control:**
```json
{
  "validate_bucket_versioning": false,
  "validate_bucket_encryption": true,
  "validate_dynamodb_table": true
}
```

## Backend Hierarchy and Detection

The root terragrunt.hcl searches for external backend configurations in this order:

1. **Same environment-project**: `envs/{environment}/{project}/**/external-s3-backend/backend-config.json`
2. **Environment level**: `envs/{environment}/*/external-s3-backend/backend-config.json` 
3. **Project level**: `projects/{project}/*/external-s3-backend/backend-config.json`

**First match wins** - allows for hierarchical backend configuration inheritance.

### Example Hierarchy

```
envs/
├── production/
│   ├── web-app/
│   │   └── us-east-1/
│   │       ├── company-backend/          # 1. Specific backend for prod web-app
│   │       │   └── backend-config.json   
│   │       └── database/                 # Uses company-backend
│   └── shared-backend/                   # 2. Fallback for all production
│       └── backend-config.json
└── staging/
    └── api-server/
        └── us-west-2/
            └── database/                 # Uses smart generated defaults (no external backend)
```

## Validation and Safety

### Automatic Validation
- S3 bucket existence and accessibility
- DynamoDB table existence and accessibility  
- Bucket versioning status (if enabled)
- Bucket encryption status (if enabled)
- KMS key validity and permissions
- Cross-region access permissions

### Common Backend Configuration Errors

```bash
# Error: Bucket not found
Error: S3 bucket 'wrong-bucket-name' not found or inaccessible.

# Error: Table not accessible
Error: DynamoDB table 'wrong-table-name' not found or inaccessible.

# Error: Versioning not enabled
Error: S3 bucket does not have versioning enabled. This is recommended for Terraform state buckets.

# Error: No encryption
Error: S3 bucket does not have server-side encryption enabled. This is recommended for Terraform state buckets.
```

### Troubleshooting

**Test Backend Access:**
```bash
# Test S3 bucket access
aws s3 ls s3://my-company-terraform-state/

# Test DynamoDB table access  
aws dynamodb describe-table --table-name my-company-terraform-locks

# Test KMS key access
aws kms describe-key --key-id alias/terraform-state-key
```

**Validate Configuration:**
```bash
cd envs/production/web-app/us-east-1/company-backend
terragrunt validate
terragrunt plan
```

## Benefits

✅ **Zero Configuration** - All resources automatically use external backend once configured  
✅ **Centralized Management** - Backend managed by infrastructure team, resources by app teams  
✅ **Security** - Supports KMS encryption, proper IAM permissions, validation  
✅ **Flexibility** - Cross-region support, custom state prefixes, hierarchical inheritance  
✅ **Migration Path** - Easy transition between external and managed backends  
✅ **Validation** - Automatic checks ensure backend is properly configured  

## Migration Scenarios

### From Manual Configuration
1. **Create external backend resource** with current bucket/table details
2. **Remove manual backend blocks** from individual terragrunt.hcl files  
3. **Test with `terragrunt plan`** to ensure no state changes

### To Managed Backends  
1. **Create managed S3 backend**: `./manage.pl add resource "new-backend:s3-backend"`
2. **Update backend-config.json** to point to new managed resources
3. **Migrate state** using `terragrunt state mv` or recreate resources
4. **Remove external backend** when migration is complete

### Gradual Migration
1. **Create external backend** for existing infrastructure
2. **Add new resources** using external backend  
3. **Migrate to managed backend** environment by environment
4. **Update configurations** to use managed backends

## Best Practices

### 1. Use JSON Configuration Files
- Easier to maintain than inline configuration
- Can be version controlled with appropriate .gitignore rules
- Clear documentation of external dependencies

### 2. Document Backend Ownership
- Include contact information for backend owners in README
- Document any constraints or requirements  
- Note planned migration paths (if applicable)

### 3. Implement Proper IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow", 
      "Action": [
        "s3:GetObject",
        "s3:PutObject", 
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::my-company-terraform-state/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/my-company-terraform-locks"
    }
  ]
}
```

### 4. Environment Consistency
- Use similar backend patterns across environments
- Maintain consistent state key prefixes
- Document differences between environments clearly

This system provides seamless integration between external S3 backends and your Terragrunt workflow, with automatic detection, validation, and zero-configuration usage!