# Smart S3 Backend Configuration

## Overview

The root `terragrunt.hcl` file now includes smart backend configuration that automatically determines the correct S3 bucket and DynamoDB table based on your directory hierarchy. You no longer need to manually configure backends for each resource!

## How It Works

### Automatic Detection

The configuration automatically detects:

1. **Environment**: From `envs/<env>/` directories (e.g., `testing`, `production`, `dev`)
2. **Project**: From `envs/<env>/<project>/` or `projects/<project>/` 
3. **Region**: From `envs/<env>/<project>/<region>/` directories
4. **State Organization**: Hierarchical state keys preserve full directory structure

### Generated Resources

For each environment-project combination:

- **S3 Bucket**: `<environment>-<project>-terraform-state`
- **DynamoDB Table**: `<environment>-<project>-terraform-locks`
- **State Key**: `<full-path>/terraform.tfstate`
- **Region**: Automatically detected from directory structure

## Examples

### Example 1: Environment-Based Resources

Directory: `envs/testing/api-server/us-west-2/database/`

```hcl
# Automatically generates:
bucket         = "testing-api-server-terraform-state"
dynamodb_table = "testing-api-server-terraform-locks"
region         = "us-west-2"
key           = "envs/testing/api-server/us-west-2/database/terraform.tfstate"
```

### Example 2: Project-Level Resources  

Directory: `projects/shared-services/_global/vpc/`

```hcl
# Automatically generates:
bucket         = "global-shared-services-terraform-state"
dynamodb_table = "global-shared-services-terraform-locks"
region         = "us-east-1"  # default region
key           = "projects/shared-services/_global/vpc/terraform.tfstate"
```

### Example 3: Multiple Databases

Directory structure:
```
envs/production/web-app/us-east-1/
├── primary-db/
├── read-replica/
└── cache-db/
```

All share the same backend:
- **Bucket**: `production-web-app-terraform-state`
- **Lock Table**: `production-web-app-terraform-locks`
- **Unique state keys** for each resource

## Creating S3 Backend Resources

Use the new `s3-backend` resource type to create the required infrastructure:

```bash
# Create S3 backend for testing environment
./manage.pl add resource "state-backend:s3-backend" -e testing -p api-server -r us-west-2

# Create S3 backend for production environment  
./manage.pl add resource "prod-state:s3-backend" -e production -p web-app -r us-east-1
```

The `s3-backend` resource creates:
- S3 bucket with versioning enabled
- Server-side encryption (AES256)
- Public access blocked
- Lifecycle rules (90-day retention for old versions)
- Appropriate tags for organization

## Global Inputs

All modules automatically receive:

```hcl
inputs = {
  environment = "testing"        # Auto-detected
  project     = "api-server"     # Auto-detected  
  region      = "us-west-2"      # Auto-detected
  name_prefix = "testing-api-server"
  
  common_tags = {
    Environment = "testing"
    Project     = "api-server"
    Region      = "us-west-2"
    ManagedBy   = "Terragrunt"
  }
}
```

## Migration from Manual Configuration

If you have existing resources with manual backend configuration:

1. **Create S3 backend resources** using `s3-backend` resource type
2. **Deploy the backends** first: `./terragrunt-deploy.pl -d envs/testing/api-server/us-west-2/state-backend`
3. **Migrate existing state** using `terragrunt state mv` or recreate resources
4. **Remove manual backend blocks** from individual terragrunt.hcl files

## Benefits

✅ **Zero configuration** - Backend automatically configured based on directory structure  
✅ **Consistent naming** - Standardized bucket and table names across all environments  
✅ **Isolated state** - Each environment-project combination has separate backend  
✅ **Hierarchical organization** - State keys preserve full directory path  
✅ **Auto-tagging** - All backend resources properly tagged for cost allocation  
✅ **Security** - All backends created with encryption and public access blocked  

## Troubleshooting

### Common Issues

1. **Backend bucket doesn't exist**: Create using `s3-backend` resource type first
2. **Permission denied**: Ensure AWS credentials have S3 and DynamoDB permissions  
3. **Region mismatch**: Directory structure determines region, ensure consistency

### Debug Backend Configuration

Add this to any terragrunt.hcl to see the detected values:

```hcl
locals {
  debug = {
    environment = local.environment
    project     = local.project  
    region      = local.region
    bucket      = local.state_bucket
    table       = local.lock_table
  }
}
```