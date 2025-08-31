# Terragrunt Infrastructure Management System

A sophisticated Perl-based infrastructure management system for organizing and deploying Terragrunt configurations with a flexible hierarchical structure and module-based architecture.

## 🏗️ Architecture Overview

This system provides a modular approach to infrastructure management with:

- **Hierarchical Directory Structure**: `envs/testing/us-west-2/z1/eks`
- **Module-Based Infrastructure**: Environment, Project, Region, Zone modules with validation
- **Template-Driven Configuration**: Auto-generated `.hcl` files with variable substitution
- **Flexible Resource Placement**: Resources can be placed at any hierarchy level
- **Standardized Naming**: Consistent resource naming across all components

## 📁 Directory Structure

```
├── admin/
│   └── templates/
│       ├── env/env.hcl           # Environment template
│       ├── project/project.hcl   # Project template  
│       ├── region/region.hcl     # Region template
│       ├── zone/zone.hcl         # Zone template
│       └── resources/            # Resource templates
│           ├── vpc/
│           ├── eks/
│           ├── iam/
│           ├── s3/
│           └── ...
├── lib/
│   ├── Infrastructure/           # Infrastructure modules
│   │   ├── Base.pm
│   │   ├── Environment.pm
│   │   ├── Project.pm
│   │   ├── Region.pm
│   │   ├── Zone.pm
│   │   └── Factory.pm
│   └── Resource/                # Resource modules
│       ├── Base.pm
│       └── Factory.pm
├── envs/                        # Environment deployments
├── projects/                    # Project configurations
├── manage.pl                    # Main management script
└── test-structure.sh           # Demo script
```

## 🚀 Quick Start

### Prerequisites

- Perl 5.10+
- Required Perl modules: `YAML::Tiny`, `JSON`
- Terragrunt and Terraform installed

### Backend Configuration (Crucial First Step!)

This framework uses a central `terragrunt.hcl` file in the root of the repository to configure the remote state backend for all modules. Before you can deploy any resources, you must set this up.

1.  **Create an S3 Bucket:** This bucket will store your Terraform state files. It must be globally unique.
    ```sh
    aws s3api create-bucket --bucket my-terragrunt-state-bucket --region us-east-1
    ```

2.  **Create a DynamoDB Table:** This table is used for state locking to prevent concurrent modifications.
    ```sh
    aws dynamodb create-table \
      --table-name my-terragrunt-locks \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
      --region us-east-1
    ```

3.  **Update `terragrunt.hcl`:** Open the `terragrunt.hcl` file in the root of this repository and update the `bucket` and `dynamodb_table` values to match the resources you just created.

    ```hcl
    # terragrunt.hcl
    remote_state {
      backend = "s3"
      config = {
        # ...
        bucket         = "my-terragrunt-state-bucket"  # <-- CHANGE THIS
        dynamodb_table = "my-terragrunt-locks"         # <-- CHANGE THIS
        # ...
      }
    }
    ```


### Basic Usage

```bash
# Create an environment
./manage.pl add env testing

# Create a project
./manage.pl add project web-app

# Create a region 
./manage.pl add region us-west-2 -e testing

# Create availability zones
./manage.pl add zone us-west-2a -e testing -r us-west-2
./manage.pl add zone us-west-2b -e testing -r us-west-2

# Add resources at different levels
./manage.pl add resource iam-roles -e testing                    # Environment level
./manage.pl add resource vpc -e testing -r us-west-2             # Region level  
./manage.pl add resource eks -e testing -r us-west-2 -z us-west-2a  # Zone level
```

### Run Demo

```bash
# Create comprehensive test structure
./test-structure.sh

# View created structure
tree envs projects
```

## 📋 Commands

### Environment Management
```bash
# Create environment
./manage.pl add env <name>

# List environments  
./manage.pl list env

# Examples
./manage.pl add env production
./manage.pl add env staging
./manage.pl add env development
```

### Project Management
```bash
# Create project
./manage.pl add project <name>

# List projects
./manage.pl list project

# Examples
./manage.pl add project web-frontend
./manage.pl add project data-pipeline
./manage.pl add project infrastructure
```

### Regional Resources
```bash
# Create region
./manage.pl add region <name> -e <environment>

# List regions in environment
./manage.pl list region -e <environment>

# Examples
./manage.pl add region us-east-1 -e production
./manage.pl add region eu-west-1 -e production
```

### Zone Management
```bash
# Create zone
./manage.pl add zone <name> -e <env> -r <region>

# List zones
./manage.pl list zone -e <env> -r <region>

# Examples
./manage.pl add zone us-east-1a -e production -r us-east-1
./manage.pl add zone us-east-1b -e production -r us-east-1
```

### Resource Management
```bash
# Add resource at different levels
./manage.pl add resource <name> [OPTIONS]

# Options:
#   -e, --env <env>        Environment name (required)
#   -r, --region <region>  Region name (for regional resources)
#   -z, --zone <zone>      Zone name (for zone-specific resources)
#   -p, --project <proj>   Project name (for project-specific resources)
#   --resource-type <type> Override auto-detected resource type

# Examples - Different hierarchy levels:
./manage.pl add resource iam-admin-role -e prod                    # Environment level
./manage.pl add resource vpc -e prod -r us-east-1                 # Region level
./manage.pl add resource eks-cluster -e prod -r us-east-1 -z us-east-1a  # Zone level
./manage.pl add resource app-database -e prod -p web-app -r us-east-1     # Project+Region level
```

### Resource Types
```bash
# List available resource types
./manage.pl list resources

# Common resource types with modules:
# - vpc: VPC and networking
# - eks: EKS clusters and node groups  
# - iam: IAM roles, policies, users, groups
# - s3: S3 buckets and configurations
# - rds: RDS databases
# - security-group: Security groups
# - alb: Application Load Balancers
```

## 🎯 Key Features

### 1. Module-Based Infrastructure

Each infrastructure component (Environment, Project, Region, Zone) has its own module with:

- **Validation Logic**: Ensures proper naming, dependencies, and format
- **Template Processing**: Auto-generates configuration files with variable substitution  
- **Pre/Post Hooks**: Extensible validation and setup logic
- **Type Detection**: Automatic detection and configuration based on names

### 2. Flexible Resource Placement

Resources can be placed at any level in the hierarchy:

```bash
# Environment level (shared across all regions)
envs/testing/iam-roles/

# Region level (region-specific)  
envs/testing/us-west-2/vpc/

# Zone level (AZ-specific)
envs/testing/us-west-2/us-west-2a/eks-nodes/

# Project+Region level
envs/testing/web-app/us-west-2/app-database/
```

### 3. Standardized Naming

Resources are automatically named using the pattern: `<resource>-<env>-<project>-<region>-<zone>` (only using variables that are set).

Examples:
- `vpc-testing-us-west-2`
- `eks-cluster-production-web-app-us-east-1-us-east-1a`
- `iam-admin-role-staging`

### 4. Template-Driven Configuration

All `.hcl` files are generated from templates with variable substitution:

```hcl
# Environment template generates:
locals {
  environment = "{{environment}}"
  env_type    = "{{env_type}}"
  is_production = {{is_production}}
  
  common_tags = {{common_tags}}
}
```

### 5. Smart Type Detection

- **Environments**: `prod/production` → production type, `dev/development` → development type
- **Projects**: `api/backend` → backend type, `web/frontend` → frontend type, `data/analytics` → data type
- **Resources**: `eks-*` → EKS type, `vpc-*` → VPC type, `iam-*` → IAM type

## ⚙️ Configuration

### Main Configuration

Configuration is stored in `admin/manage-config.yaml`:

```yaml
directories:
  environments: "envs"
  projects: "projects"
  modules: "modules"
  environment_structure:
    regional_placement: "direct"  # or "project_based"
    default_project: "h2g2"

templates:
  base_path: "admin/templates"
  environment: "env"
  region: "region"
  zone: "zone"
  project: "project"

files:
  environment: "env.hcl"
  region: "region.hcl"
  project: "project.hcl"
  terragrunt: "terragrunt.hcl"
```

### Resource Modules

Each resource type can have its own module in `admin/templates/resources/<type>/Resource.pm`:

```perl
package admin::templates::resources::eks::Resource;
use strict;
use warnings;
use parent 'Resource::Base';

sub get_resource_type { return 'eks'; }

sub get_terraform_source {
    return 'git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v19.21.0';
}

sub get_default_inputs {
    my $self = shift;
    return {
        cluster_version => '1.28',
        enable_irsa => 'true',
        # ... other defaults
    };
}
```

## 🛡️ Safety Features

### Duplicate Protection
```bash
# Won't overwrite existing resources
./manage.pl add env testing
# Output: Env testing already exists. Use -f to force overwrite.

# Force overwrite if needed
./manage.pl add env testing --force
```

### Validation
- Environment name format validation
- AWS region format checking  
- Zone/region consistency validation
- Dependency checking (region exists before creating zone)
- Reserved name protection

### Dry Run Mode
```bash
# Preview what would be created
./manage.pl add env testing --dry-run
./manage.pl add resource vpc -e testing -r us-west-2 --dry-run
```

## 📝 Examples

### Complete EKS Setup

```bash
# 1. Create base infrastructure
./manage.pl add env production
./manage.pl add project web-platform
./manage.pl add region us-east-1 -e production

# 2. Create zones
./manage.pl add zone us-east-1a -e production -r us-east-1
./manage.pl add zone us-east-1b -e production -r us-east-1
./manage.pl add zone us-east-1c -e production -r us-east-1

# 3. Add networking
./manage.pl add resource vpc -e production -r us-east-1

# 4. Add EKS cluster  
./manage.pl add resource eks-cluster -e production -r us-east-1

# 5. Add node groups per zone
./manage.pl add resource eks-nodes -e production -r us-east-1 -z us-east-1a
./manage.pl add resource eks-nodes -e production -r us-east-1 -z us-east-1b
./manage.pl add resource eks-nodes -e production -r us-east-1 -z us-east-1c

# 6. Add IAM resources
./manage.pl add resource iam-cluster-role -e production
./manage.pl add resource iam-node-role -e production

# Result structure:
# envs/production/
# ├── env.hcl
# ├── iam-cluster-role/
# ├── iam-node-role/  
# └── us-east-1/
#     ├── region.hcl
#     ├── vpc/
#     ├── eks-cluster/
#     ├── us-east-1a/
#     │   ├── zone.hcl
#     │   └── eks-nodes/
#     ├── us-east-1b/
#     │   ├── zone.hcl  
#     │   └── eks-nodes/
#     └── us-east-1c/
#         ├── zone.hcl
#         └── eks-nodes/
```

### Multi-Environment Setup

```bash
# Create environments
./manage.pl add env development  
./manage.pl add env staging
./manage.pl add env production

# Create shared project
./manage.pl add project api-backend

# Regional deployment per environment
for env in development staging production; do
  ./manage.pl add region us-west-2 -e $env
  ./manage.pl add resource vpc -e $env -r us-west-2
  ./manage.pl add resource eks-cluster -e $env -r us-west-2
done

# Environment-specific resources
./manage.pl add resource iam-dev-roles -e development
./manage.pl add resource iam-prod-roles -e production
```

## 🐛 Troubleshooting

### Common Issues

**Module not found errors:**
```bash
# Ensure lib/ is in Perl path
export PERL5LIB="./lib:$PERL5LIB"
```

**Permission errors:**
```bash
# Make manage.pl executable
chmod +x manage.pl
```

**Template not found:**
```bash
# Check template directory exists
ls -la admin/templates/resources/
```

### Validation Errors

**Invalid region name:**
```
Region name must contain only lowercase letters, numbers, and hyphens
```

**Missing dependencies:**
```
Environment 'testing' does not exist. Create it first.
Region 'us-west-2' does not exist. Create it first.
```

### Debug Mode

```bash
# Enable verbose output
./manage.pl add resource vpc -e testing -r us-west-2 --verbose

# Check syntax
perl -c manage.pl
perl -Ilib -c lib/Infrastructure/Environment.pm
```

## 🔧 Extending the System

### Adding New Resource Types

1. Create resource template directory:
```bash
mkdir -p admin/templates/resources/new-service
```

2. Add terragrunt.hcl template:
```hcl
# admin/templates/resources/new-service/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/example/terraform-new-service.git?ref=v1.0.0"
}

inputs = {
  name = "{{full_name}}"
  tags = {{common_tags}}
  # ... other inputs
}
```

3. Optional: Add Resource module:
```perl
# admin/templates/resources/new-service/Resource.pm
package admin::templates::resources::newservice::Resource;
use parent 'Resource::Base';

sub get_resource_type { return 'new-service'; }
```

### Adding Infrastructure Hooks

Extend Infrastructure modules with custom logic:

```perl
# lib/Infrastructure/Environment.pm
sub pre_create {
    my $self = shift;
    # Custom validation or setup logic
    $self->SUPER::pre_create();
}

sub post_create {
    my $self = shift;
    # Custom post-creation tasks
    $self->SUPER::post_create();
}
```

## 📚 Documentation

For detailed documentation, see the [docs/](docs/) folder:
- [docs/guides/CUSTOM_RESOURCE_NAMING_GUIDE.md](docs/guides/CUSTOM_RESOURCE_NAMING_GUIDE.md) - Advanced resource naming patterns
- [docs/guides/EXTERNAL_VPC_GUIDE.md](docs/guides/EXTERNAL_VPC_GUIDE.md) - External VPC integration
- [docs/guides/EXTERNAL_S3_BACKEND_GUIDE.md](docs/guides/EXTERNAL_S3_BACKEND_GUIDE.md) - External S3 backend setup
- [docs/guides/BACKEND_CONFIGURATION.md](docs/guides/BACKEND_CONFIGURATION.md) - Backend configuration details

Browse all documentation: [docs/README.md](docs/README.md)

## 📚 Additional Resources

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [terraform-aws-modules](https://github.com/terraform-aws-modules)

## 🤝 Contributing

1. Follow existing code patterns and Perl best practices
2. Add validation logic for new components
3. Update templates and documentation
4. Test with `--dry-run` mode first
5. Update `test-structure.sh` if adding new features

## 📄 License

Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
