# Docker Setup for Terragrunt Infrastructure Management System

This document explains how to use Docker to run the Terragrunt Infrastructure Management System in a containerized environment.

## 🐳 Quick Start

### Option 1: Using the convenient script (Recommended)
```bash
# Build and run interactively
./docker/docker-run.sh --build

# Run with AWS credentials from environment
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_REGION=us-east-1
./docker/docker-run.sh

# Run with AWS credentials from ~/.aws directory
./docker/docker-run.sh --aws-dir

# Run a specific command
./docker/docker-run.sh './manage.pl list env'
```

### Option 2: Using Docker Compose
```bash
# Edit docker/docker-compose.yml to uncomment AWS credential mounts
# Then run:
docker-compose up -d terragrunt-manager
docker-compose exec terragrunt-manager bash
```

### Option 3: Direct Docker commands
```bash
# Build the image
docker build -t terragrunt-infra-manager .

# Run interactively
docker run -it --rm \
  -v $(pwd):/home/terragrunt/workspace \
  -v ~/.aws:/home/terragrunt/.aws:ro \
  terragrunt-infra-manager
```

## 🔧 What's Included

The Docker image includes:

### Core Tools
- **Terraform** (latest via tfenv)
- **Terragrunt** (latest via tgenv) 
- **AWS CLI v2** with Session Manager plugin
- **Git** for repository operations
- **GitHub CLI** for GitHub operations

### Perl Environment
- **Perl 5.34** with comprehensive module collection
- **All required modules**: YAML::Tiny, JSON, File::*, Getopt::Long, etc.
- **Development tools**: cpanm, testing modules
- **AWS integration**: Paws (AWS SDK for Perl)

### Additional Utilities
- **jq** for JSON processing
- **yq** for YAML processing  
- **tree** for directory visualization
- **vim/nano** for editing
- **Standard Unix tools**

## 🔐 AWS Authentication Methods

### Method 1: Environment Variables (Default)
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
./docker/docker-run.sh
```

### Method 2: AWS Directory Mount
```bash
# Mounts your ~/.aws directory read-only
./docker/docker-run.sh --aws-dir
```

### Method 3: Docker Compose Configuration
Edit `docker/docker-compose.yml` and uncomment:
```yaml
volumes:
  - ~/.aws:/home/terragrunt/.aws:ro
```

### Method 4: IAM Roles (ECS/EKS/EC2)
When running on AWS infrastructure, the container will automatically use instance/pod IAM roles.

## 📋 Usage Examples

### Interactive Development
```bash
# Start development environment with debug logging
./docker/docker-run.sh --build --dev

# Inside container:
./manage.pl add env testing
./manage.pl add resource vpc -e testing -r us-west-2
./bin/terragrunt-deploy.pl --list
```

### Running Specific Commands
```bash
# List available resource types
./docker/docker-run.sh './manage.pl list resources'

# Create infrastructure from config
./docker/docker-run.sh './manage.pl add --config infrastructure.json'

# Run deployment
./docker/docker-run.sh './bin/terragrunt-deploy.pl -d envs/testing/h2g2'

# Check Terraform/Terragrunt versions
./docker/docker-run.sh 'terraform version && terragrunt --version'
```

### AWS Operations
```bash
# Test AWS connectivity
./docker/docker-run.sh 'aws sts get-caller-identity'

# List S3 buckets
./docker/docker-run.sh 'aws s3 ls'

# Check EKS clusters
./docker/docker-run.sh 'aws eks list-clusters --region us-east-1'
```

## 🚀 Development Workflow

### 1. Initial Setup
```bash
# Build the development image
./docker/docker-run.sh --build --dev

# Create test infrastructure
./manage.pl add env development
./manage.pl add project web-app
./manage.pl add region us-west-2 -e development -p web-app
```

### 2. Infrastructure Management
```bash
# Add resources
./manage.pl add resource vpc -e development -p web-app -r us-west-2
./manage.pl add resource eks-cluster -e development -p web-app -r us-west-2

# Generate module analysis
./admin/terraform-module-analyzer.pl

# Deploy infrastructure  
./bin/terragrunt-deploy.pl -d envs/development/web-app/us-west-2 --plan
```

### 3. Testing and Validation
```bash
# Run tests
./bin/run_tests.pl

# Validate configuration
./manage.pl add resource test-vpc -e test-env -r us-east-1 --dry-run

# Check deployment status
./bin/terragrunt-deploy.pl -d envs/development --list
```

## 🔧 Docker Script Options

The `docker-run.sh` script supports various options:

```bash
./docker/docker-run.sh [OPTIONS] [COMMAND]

Options:
  -b, --build              Build the Docker image before running
  -d, --dev                Run in development mode with debug logging
  -a, --aws-dir            Mount ~/.aws directory (default: use env vars)
  -e, --env-only           Use only environment variables for AWS auth
  -n, --name NAME          Container name (default: terragrunt-manager)
  -t, --tag TAG            Image tag (default: latest)
  -v, --verbose            Verbose output
  -h, --help               Show help message
```

## 📁 Volume Mounts

The container uses these volume mounts:

- **Workspace**: `$(pwd):/home/terragrunt/workspace` (your project files)
- **AWS Creds**: `~/.aws:/home/terragrunt/.aws:ro` (optional, read-only)
- **SSH Keys**: `~/.ssh:/home/terragrunt/.ssh:ro` (optional, for git)
- **Terragrunt Cache**: Named volume for `.terragrunt-cache`
- **Terraform Cache**: Named volume for `.terraform.d`
- **CPAN Cache**: Named volume for Perl modules

## 🔍 Troubleshooting

### Container Build Issues
```bash
# Clean build (remove cache)
docker build --no-cache -t terragrunt-infra-manager .

# Check build logs
docker build -t terragrunt-infra-manager . 2>&1 | tee build.log
```

### AWS Authentication Issues
```bash
# Test AWS credentials inside container
./docker/docker-run.sh 'aws sts get-caller-identity'

# Check mounted credentials
./docker/docker-run.sh 'ls -la ~/.aws/'

# Verify environment variables
./docker/docker-run.sh 'env | grep AWS'
```

### Permission Issues
```bash
# Check file permissions
ls -la docker/docker-run.sh

# Make script executable
chmod +x docker/docker-run.sh

# Check Docker daemon
docker info
```

### Perl Module Issues
```bash
# Test Perl environment
./docker/docker-run.sh 'perl -c manage.pl'

# Check installed modules
./docker/docker-run.sh 'perl -MYAML::Tiny -e "print \"YAML::Tiny OK\n\""'

# Install additional modules
./docker/docker-run.sh 'cpanm Module::Name'
```

### Performance Optimization
```bash
# Use named volumes for caching
docker volume create terragrunt-cache
docker volume create terraform-cache

# Run with more resources
docker run --memory=4g --cpus=4 ...

# Use Docker BuildKit for faster builds
DOCKER_BUILDKIT=1 docker build -t terragrunt-infra-manager .
```

## 🏷️ Image Information

- **Base Image**: Ubuntu 22.04 LTS
- **User**: terragrunt (non-root, UID 1000)
- **Working Directory**: `/home/terragrunt/workspace`
- **Entry Point**: Custom script with version information
- **Health Check**: Validates Terraform, Terragrunt, and AWS CLI

## 🔄 Updates and Maintenance

### Updating Tools
```bash
# Rebuild to get latest versions
./docker/docker-run.sh --build

# Update Terraform
./docker/docker-run.sh 'tfenv install latest && tfenv use latest'

# Update Terragrunt  
./docker/docker-run.sh 'tgenv install latest && tgenv use latest'

# Update AWS CLI (requires rebuild)
```

### Managing Docker Resources
```bash
# Clean up containers
docker container prune

# Clean up volumes (be careful!)
docker volume prune

# Clean up images
docker image prune

# See disk usage
docker system df
```

This Docker setup provides a complete, portable environment for infrastructure management while maintaining security and flexibility for different authentication methods.