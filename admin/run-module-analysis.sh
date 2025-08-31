#!/bin/bash

# Terraform Module Analysis Runner
# This script runs the Perl-based Terraform module analyzer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Terraform Module Analysis Runner"
echo "================================"
echo "Workspace: $WORKSPACE_ROOT"
echo "Script: $SCRIPT_DIR/terraform-module-analyzer.pl"
echo ""

# Check if Perl script exists
if [[ ! -f "$SCRIPT_DIR/terraform-module-analyzer.pl" ]]; then
    echo "Error: terraform-module-analyzer.pl not found in $SCRIPT_DIR"
    exit 1
fi

# Check if Perl is available
if ! command -v perl &> /dev/null; then
    echo "Error: Perl is not installed or not in PATH"
    exit 1
fi

# Check if required Perl modules are available
echo "Checking Perl dependencies..."
perl -e "use JSON; use File::Path; use File::Find; use Getopt::Long; use Cwd; use POSIX;" 2>/dev/null || {
    echo "Error: Required Perl modules not available. Please install:"
    echo "  - JSON"
    echo "  - File::Path"
    echo "  - File::Find"
    echo "  - Getopt::Long"
    echo "  - Cwd"
    echo "  - POSIX"
    echo ""
    echo "You can install them with:"
    echo "  cpan JSON File::Path File::Find Getopt::Long Cwd POSIX"
    exit 1
}

echo "Perl dependencies OK"
echo ""

# Parse command line arguments
DRY_RUN=false
VERBOSE=false
FORCE=false
WORK_DIR="/tmp/terraform_module_analysis"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run           Show what would be done without executing"
            echo "  -v, --verbose       Verbose output"
            echo "  -f, --force         Force re-cloning of repositories"
            echo "  --work-dir <path>   Working directory for git operations"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Run complete analysis"
            echo "  $0"
            echo ""
            echo "  # Dry run to see what would be done"
            echo "  $0 --dry-run"
            echo ""
            echo "  # Run with verbose output"
            echo "  $0 -v"
            echo ""
            echo "  # Force re-cloning of repositories"
            echo "  $0 -f"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build command
CMD="perl $SCRIPT_DIR/terraform-module-analyzer.pl"

if [[ "$DRY_RUN" == "true" ]]; then
    CMD="$CMD --dry-run"
fi

if [[ "$VERBOSE" == "true" ]]; then
    CMD="$CMD --verbose"
fi

if [[ "$FORCE" == "true" ]]; then
    CMD="$CMD --force"
fi

if [[ "$WORK_DIR" != "/tmp/terraform_module_analysis" ]]; then
    CMD="$CMD --work-dir '$WORK_DIR'"
fi

echo "Running: $CMD"
echo ""

# Change to workspace root and run
cd "$WORKSPACE_ROOT"
eval $CMD

echo ""
echo "Analysis complete!"
echo "Results saved to: $WORKSPACE_ROOT/admin/"
echo "Working directory: $WORK_DIR"
