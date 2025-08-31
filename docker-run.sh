#!/bin/bash
#
# Docker Run Script for Terragrunt Infrastructure Management System
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="terragrunt-infra-manager"
TAG="latest"
CONTAINER_NAME="terragrunt-manager"
AWS_CREDS_MODE="env"
BUILD_IMAGE=false
DEV_MODE=false
VERBOSE=false

# Functions
print_usage() {
    echo "Terragrunt Infrastructure Management System - Docker Runner"
    echo ""
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Options:"
    echo "  -b, --build              Build the Docker image before running"
    echo "  -d, --dev                Run in development mode with debug logging"
    echo "  -a, --aws-dir            Mount ~/.aws directory (default: use env vars)"
    echo "  -e, --env-only           Use only environment variables for AWS auth"
    echo "  -n, --name NAME          Container name (default: $CONTAINER_NAME)"
    echo "  -t, --tag TAG            Image tag (default: $TAG)"
    echo "  -v, --verbose            Verbose output"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Commands:"
    echo "  If no command is provided, starts an interactive bash shell"
    echo "  Otherwise, runs the provided command in the container"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive shell"
    echo "  $0 --build --dev                     # Build and run in dev mode"
    echo "  $0 --aws-dir ./manage.pl list env    # Mount AWS dir and list environments"
    echo "  $0 './manage.pl add env testing'     # Run specific command"
    echo "  $0 'terragrunt --version'            # Check terragrunt version"
    echo ""
    echo "AWS Authentication:"
    echo "  Method 1 (Environment Variables - default):"
    echo "    export AWS_ACCESS_KEY_ID=your-key"
    echo "    export AWS_SECRET_ACCESS_KEY=your-secret"
    echo "    export AWS_REGION=us-east-1"
    echo ""
    echo "  Method 2 (AWS Directory Mount):"
    echo "    $0 --aws-dir [command]"
    echo ""
    echo "  Method 3 (Docker Compose):"
    echo "    Uncomment AWS volume mounts in docker-compose.yml"
    echo "    docker-compose up -d terragrunt-manager"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD_IMAGE=true
            shift
            ;;
        -d|--dev)
            DEV_MODE=true
            CONTAINER_NAME="terragrunt-dev"
            shift
            ;;
        -a|--aws-dir)
            AWS_CREDS_MODE="mount"
            shift
            ;;
        -e|--env-only)
            AWS_CREDS_MODE="env"
            shift
            ;;
        -n|--name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Remaining arguments are the command to run
COMMAND="$*"
if [[ -z "$COMMAND" ]]; then
    COMMAND="/bin/bash"
fi

log_info "Starting Terragrunt Infrastructure Management System"

# Build image if requested
if [[ "$BUILD_IMAGE" == true ]]; then
    log_info "Building Docker image: $IMAGE_NAME:$TAG"
    docker build -t "$IMAGE_NAME:$TAG" .
    log_success "Image built successfully"
fi

# Check if image exists
if ! docker image inspect "$IMAGE_NAME:$TAG" >/dev/null 2>&1; then
    log_warning "Image $IMAGE_NAME:$TAG not found. Building it now..."
    docker build -t "$IMAGE_NAME:$TAG" .
    log_success "Image built successfully"
fi

# Prepare Docker run command
DOCKER_ARGS=(
    "run"
    "--rm"
    "-it"
    "--name" "$CONTAINER_NAME"
    "--hostname" "terragrunt-manager"
    "-v" "$PWD:/home/terragrunt/workspace"
    "-w" "/home/terragrunt/workspace"
)

# Add environment variables
if [[ "$DEV_MODE" == true ]]; then
    log_info "Running in development mode with debug logging"
    DOCKER_ARGS+=("-e" "TF_LOG=DEBUG")
    DOCKER_ARGS+=("-e" "TG_LOG=DEBUG")
    DOCKER_ARGS+=("-e" "PERL_DL_NONLAZY=1")
else
    DOCKER_ARGS+=("-e" "TF_LOG=${TF_LOG:-}")
    DOCKER_ARGS+=("-e" "TG_LOG=${TG_LOG:-}")
fi

# Add AWS configuration
case "$AWS_CREDS_MODE" in
    "mount")
        if [[ -d "$HOME/.aws" ]]; then
            log_info "Mounting AWS credentials directory: $HOME/.aws"
            DOCKER_ARGS+=("-v" "$HOME/.aws:/home/terragrunt/.aws:ro")
        else
            log_warning "AWS directory $HOME/.aws not found. Falling back to environment variables."
            AWS_CREDS_MODE="env"
        fi
        ;;
    "env")
        log_info "Using AWS environment variables for authentication"
        ;;
esac

# Add AWS environment variables
AWS_VARS=(
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_SESSION_TOKEN"
    "AWS_REGION"
    "AWS_DEFAULT_REGION"
    "AWS_PROFILE"
)

for var in "${AWS_VARS[@]}"; do
    if [[ -n "${!var}" ]]; then
        DOCKER_ARGS+=("-e" "$var=${!var}")
        if [[ "$VERBOSE" == true ]]; then
            if [[ "$var" =~ (KEY|TOKEN) ]]; then
                log_info "Setting $var=***"
            else
                log_info "Setting $var=${!var}"
            fi
        fi
    fi
done

# Add cache volumes for better performance
DOCKER_ARGS+=(
    "-v" "terragrunt-cache:/home/terragrunt/.terragrunt-cache"
    "-v" "terraform-cache:/home/terragrunt/.terraform.d"
    "-v" "cpan-cache:/home/terragrunt/.cpanm"
)

# Add SSH keys if they exist (for git operations)
if [[ -d "$HOME/.ssh" && "$AWS_CREDS_MODE" == "mount" ]]; then
    log_info "Mounting SSH keys for git operations"
    DOCKER_ARGS+=("-v" "$HOME/.ssh:/home/terragrunt/.ssh:ro")
fi

# Final arguments
DOCKER_ARGS+=("$IMAGE_NAME:$TAG")

# Show final command if verbose
if [[ "$VERBOSE" == true ]]; then
    log_info "Docker command: docker ${DOCKER_ARGS[*]} $COMMAND"
fi

# Check for existing container and remove it
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    log_warning "Stopping and removing existing container: $CONTAINER_NAME"
    docker container stop "$CONTAINER_NAME" >/dev/null
    docker container rm "$CONTAINER_NAME" >/dev/null
fi

# Run the container
log_info "Starting container: $CONTAINER_NAME"
log_info "Command: $COMMAND"
echo ""

exec docker "${DOCKER_ARGS[@]}" $COMMAND