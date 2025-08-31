# Terraform Module Analyzer (Perl)

This directory contains a Perl-based implementation of the Terraform module analysis functionality, replicating the features of the Python scripts in `admin/api/`.

## Overview

The Perl Terraform Module Analyzer scans all `terragrunt.hcl` files in your workspace, extracts module information, clones repositories, analyzes `variables.tf` files, and generates comprehensive input schemas and documentation.

## Features

✅ **Module Discovery**: Automatically finds all Terraform modules used in terragrunt configurations  
✅ **Unique Module Detection**: Identifies duplicate modules and creates a unified view  
✅ **Repository Cloning**: Clones module repositories to analyze their structure  
✅ **Variable Extraction**: Parses `variables.tf` files to extract variable definitions  
✅ **Schema Generation**: Creates JSON schemas following JSON Schema Draft-07 specification  
✅ **Input File Creation**: Generates `inputs.json` files for each deployment directory  
✅ **Comprehensive Analysis**: Saves detailed analysis results for API consumption  

## Quick Start

### 1. Run Complete Analysis
```bash
# From the admin directory
./run-module-analysis.sh

# Or from workspace root
admin/run-module-analysis.sh
```

### 2. Dry Run (Preview)
```bash
# See what would be done without executing
./run-module-analysis.sh --dry-run
```

### 3. Verbose Output
```bash
# Get detailed progress information
./run-module-analysis.sh -v
```

## Scripts

### `terraform-module-analyzer.pl`
The main Perl script that performs the complete analysis workflow.

**Usage:**
```bash
perl terraform-module-analyzer.pl [OPTIONS]
```

**Options:**
- `-v, --verbose`: Verbose output
- `--dry-run`: Show what would be done without executing
- `-f, --force`: Force re-cloning of repositories
- `--work-dir <path>`: Working directory for git operations (default: `/tmp/terraform_module_analysis`)
- `-h, --help`: Show help message

### `run-module-analysis.sh`
A convenient shell wrapper that handles dependency checking and provides a user-friendly interface.

**Usage:**
```bash
./run-module-analysis.sh [OPTIONS]
```

**Options:**
- `--dry-run`: Show what would be done without executing
- `-v, --verbose`: Verbose output
- `-f, --force`: Force re-cloning of repositories
- `--work-dir <path>`: Working directory for git operations
- `-h, --help`: Show help message

## What It Does

### Step 1: Module Extraction
- Scans all `terragrunt.hcl` files recursively
- Extracts `source = "..."` lines
- Parses different module source formats:
  - `git::https://github.com/org/repo.git?ref=v1.0.0`
  - `git@github.com:org/repo.git//modules/module-name`
  - Local paths and other formats

### Step 2: Unique Module Analysis
- Identifies duplicate modules across the workspace
- Groups modules by type (git_https, git_ssh, unknown)
- Creates a unified view of all modules

### Step 3: Module Schema Generation
- Clones repositories to `/tmp/terraform_module_analysis/`
- Finds and parses `variables.tf` files
- Extracts variable definitions, types, descriptions, defaults, and validation rules
- Generates JSON schemas for each module

### Step 4: Input File Generation
- Creates `inputs.json` files in each terragrunt directory
- Maps modules to their usage locations
- Provides structured input templates with descriptions and validation

### Step 5: Results Storage
- Saves comprehensive analysis to `admin/module_analysis.json`
- Stores module schemas in `admin/module_schemas.json`
- Provides summary statistics and metadata

## Output Files

### Generated Files
- **`admin/module_analysis.json`**: Complete analysis results with all module information
- **`admin/module_schemas.json`**: Individual JSON schemas for each module
- **`*/inputs.json`**: Input templates for each deployment directory

### Input File Structure
```json
{
  "module_info": {
    "file_path": "path/to/terragrunt.hcl",
    "modules": [
      {
        "source": "git::https://github.com/org/repo.git?ref=v1.0.0",
        "repo": "https://github.com/org/repo.git",
        "module_path": "modules/example",
        "ref": "v1.0.0",
        "type": "git_https"
      }
    ]
  },
  "variables": {
    "instance_type": {
      "description": "EC2 instance type",
      "type": "string",
      "required": true,
      "default": null,
      "value": null,
      "validation": []
    },
    "instance_count": {
      "description": "Number of instances",
      "type": "number",
      "required": false,
      "default": 1,
      "value": 1,
      "validation": []
    }
  }
}
```

## Module Types Supported

### Git HTTPS Modules
- Format: `git::https://github.com/org/repo.git?ref=v1.0.0`
- Examples: terraform-aws-modules, public repositories
- Supports version tags and submodule paths

### Git SSH Modules
- Format: `git@github.com:org/repo.git//modules/module-name`
- Examples: Private repositories, custom modules
- Automatically converts to HTTPS for cloning

### Local Modules
- Format: `../../modules/example` or `${get_repo_root()}/modules/example`
- Examples: Workspace-local modules, relative paths

## Variable Extraction

The analyzer extracts the following information from `variables.tf` files:

- **Variable names** and types
- **Descriptions** from Terraform comments
- **Default values** and required status
- **Validation rules** and error messages
- **Type information** (string, number, bool, list, map, object)

## Dependencies

### Required Perl Modules
- `JSON`: JSON encoding/decoding
- `File::Path`: Directory creation and removal
- `File::Find`: Recursive file searching
- `Getopt::Long`: Command-line argument parsing
- `Cwd`: Current working directory functions
- `POSIX`: POSIX functions (strftime)

### System Requirements
- Perl 5.10 or higher
- Git (for cloning repositories)
- Access to module repositories (SSH keys or HTTPS credentials)

## Installation

### 1. Install Perl Dependencies
```bash
# Using cpan
cpan JSON File::Path File::Find Getopt::Long Cwd POSIX

# Or using your system package manager
# Ubuntu/Debian: sudo apt-get install libjson-perl libfile-path-perl
# CentOS/RHEL: sudo yum install perl-JSON perl-File-Path
# macOS: brew install perl
```

### 2. Verify Installation
```bash
# Check if script is executable
ls -la admin/terraform-module-analyzer.pl

# Test dependency check
admin/run-module-analysis.sh --help
```

## Usage Examples

### Basic Analysis
```bash
# Run complete analysis
admin/run-module-analysis.sh

# Check results
ls -la admin/
cat admin/module_analysis.json | jq '.summary'
```

### Advanced Usage
```bash
# Force re-cloning of repositories
admin/run-module-analysis.sh -f

# Use custom working directory
admin/run-module-analysis.sh --work-dir /tmp/my_analysis

# Verbose output with dry run
admin/run-module-analysis.sh -v --dry-run
```

### Integration with Existing Workflow
```bash
# Run analysis before deployment
admin/run-module-analysis.sh

# Use generated inputs.json files
cat envs/prod/h2g2/us-west-2/deployer/inputs.json

# Check module schemas
cat admin/module_schemas.json | jq 'keys'
```

## Troubleshooting

### Common Issues

#### 1. Perl Module Not Found
```bash
# Install missing module
cpan ModuleName

# Or check what's available
perl -MCPAN -e 'print "ModuleName is available\n" if eval "require ModuleName"'
```

#### 2. Git Clone Failures
```bash
# Check SSH key configuration
ssh -T git@github.com

# Verify HTTPS credentials
git clone https://github.com/org/repo.git /tmp/test
```

#### 3. Permission Issues
```bash
# Make scripts executable
chmod +x admin/*.pl admin/*.sh

# Check working directory permissions
ls -la /tmp/terraform_module_analysis/
```

### Debug Mode
```bash
# Run with verbose output
admin/run-module-analysis.sh -v

# Check temporary files
ls -la /tmp/terraform_module_analysis/

# Examine generated files
find . -name "inputs.json" -exec head -20 {} \;
```

## Comparison with Python Version

| Feature | Python Version | Perl Version |
|---------|----------------|--------------|
| **Module Discovery** | ✅ | ✅ |
| **Repository Cloning** | ✅ | ✅ |
| **Variable Parsing** | ✅ | ✅ |
| **Schema Generation** | ✅ | ✅ |
| **Input File Creation** | ✅ | ✅ |
| **Dependencies** | Python 3.7+ | Perl 5.10+ |
| **Performance** | Good | Excellent |
| **Memory Usage** | Higher | Lower |
| **Installation** | pip requirements | cpan modules |

## Future Enhancements

### Planned Features
- **Terragrunt Integration**: Generate terragrunt.hcl from inputs.json
- **Configuration Validation**: Validate existing configurations against schemas
- **API Server**: REST API for configuration management
- **Template Generation**: Create configuration templates and wizards

### Contributing
The Perl implementation is designed to be easily extensible. Key areas for contribution:
- Additional module source format support
- Enhanced variable type parsing
- Integration with Terraform Registry
- Performance optimizations

## Notes

- All git operations use `/tmp/terraform_module_analysis` by default
- Scripts automatically find workspace root by looking for `terragrunt.hcl`
- Generated schemas follow JSON Schema standards
- Input files are created in-place for easy access
- The analyzer is designed to be non-destructive and safe to run multiple times

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Run with verbose output: `admin/run-module-analysis.sh -v`
3. Examine the generated files for clues
4. Check Perl module availability: `perl -e "use ModuleName; print 'OK'"`

The Perl implementation provides the same functionality as the Python version with improved performance and lower resource requirements.
