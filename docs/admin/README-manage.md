# Infrastructure Management Script

The `manage.pl` script provides a command-line interface for managing infrastructure components in your Terragrunt workspace.

## Features

- **Add new environments** with pre-configured templates
- **Add global resources** for environments
- **Add regional resources** with environment context
- **Add availability zones** with region and environment context
- **List existing components** to understand your current infrastructure
- **Template-based creation** using files from `admin/templates/`

## Usage

### Basic Syntax

```bash
./manage.pl <ACTION> <TARGET> [OPTIONS]
```

### Actions

- `add` - Create new infrastructure components
- `list` - List existing infrastructure components
- `remove` - Remove infrastructure components (not yet implemented)
- `show` - Show details of infrastructure components (not yet implemented)

### Targets

- `env <name>` - Environment (dev, staging, prod)
- `project <name>` - Project (h2g2, etc.)
- `global -e <env>` - Global resources for environment
- `region <name> -e <env>` - Regional resources for environment
- `zone <name> -e <env> -r <region>` - Availability zone for region/environment

### Options

- `-e, --env <env>` - Environment name
- `-p, --project <proj>` - Project name
- `-r, --region <reg>` - Region name
- `-z, --zone <zone>` - Zone name
- `-c, --config <file>` - JSON configuration file for bulk operations
- `--config-file <file>` - Script configuration file (default: admin/manage-config.yaml)
- `-v, --verbose` - Verbose output
- `--dry-run` - Show what would be done without executing
- `-f, --force` - Force overwrite of existing files
- `-h, --help` - Show help message

## Examples

### Adding a New Environment

```bash
# Add staging environment
./manage.pl add env "staging"

# Add with dry run to see what would happen
./manage.pl add env "staging" --dry-run
```

### Adding Global Resources

```bash
# Add global resources for dev environment
./manage.pl add global -e dev

# Add with verbose output
./manage.pl add global -e dev -v
```

### Adding Regional Resources

```bash
# Add us-east-1 region for dev environment
./manage.pl add region "us-east-1" -e dev

# Add with dry run
./manage.pl add region "us-east-1" -e dev --dry-run
```

### Adding Availability Zones

```bash
# Add z1a zone in us-east-1 region for dev environment
./manage.pl add zone "z1a" -e dev -r "us-east-1"

# Add with force overwrite
./manage.pl add zone "z1a" -e dev -r "us-east-1" -f
```

### Adding Multiple Components from JSON Config

```bash
# Add multiple components from JSON configuration file
./manage.pl add --config infrastructure.json

# Add with dry run to see what would happen
./manage.pl add --config infrastructure.json --dry-run

# Add with verbose output
./manage.pl add --config infrastructure.json -v
```

### Listing Components

```bash
# List all environments
./manage.pl list env

# List regions in gdev environment
./manage.pl list region -e gdev

# List zones in h2g2/eu-west-1 region of gdev environment
./manage.pl list zone -e gdev -r "h2g2/eu-west-1"
```

## Script Configuration

The script uses a YAML configuration file to control directory structure, file naming, and template locations. This makes it flexible for different organizations and systems.

### Configuration File

- **Default**: `admin/manage-config.yaml`
- **Override**: Use `--config-file <file>` option
- **Format**: YAML configuration

### Configuration Options

```yaml
directories:
  environments: "envs"           # Where environments are stored
  projects: "projects"           # Where projects are stored
  modules: "modules"             # Where Terraform modules are stored
  
  environment_structure:
    global: "_global"            # Global resources directory name
    regional_placement: "direct" # "direct" or "project_based"
    default_project: "h2g2"       # Default project for regional resources
    regional: "_regional"        # Regional resources directory name
    zones: "zones"               # Zones directory name

templates:
  base_path: "admin/templates"   # Base template directory
  environment: "env"             # Environment template subdirectory
  global: "global"               # Global template subdirectory
  region: "region"               # Region template subdirectory
  zone: "zone"                   # Zone template subdirectory
  project: "project"             # Project template subdirectory

files:
  environment: "env.hcl"         # Environment config file name
  region: "region.hcl"           # Region config file name
  project: "project.hcl"         # Project config file name
  terragrunt: "terragrunt.hcl"  # Terragrunt config file name
```

### Directory Structure Modes

#### Direct Placement (default)
```
envs/
├── <environment>/
│   ├── env.hcl
│   ├── _global/
│   │   └── terragrunt.hcl
│   └── <region>/
│       ├── region.hcl
│       └── <zone>/
│           └── terragrunt.hcl
```

#### Project-Based Placement
```
environments/
├── <environment>/
│   ├── env.hcl
│   ├── global/
│   │   └── terragrunt.hcl
│   └── <project>/
│       ├── project.hcl
│       └── <region>/
│           ├── region.hcl
│           └── <zone>/
│               └── terragrunt.hcl
```

### Using Different Configurations

```bash
# Use default configuration
./manage.pl add env "staging"

# Use alternative configuration
./manage.pl --config-file admin/alternative-config.yaml add env "staging"

# Use custom configuration for different organization
./manage.pl --config-file /path/to/org-config.yaml add env "production"
```

### Benefits of Configuration System

- **Flexibility** - Adapt to different organizational structures
- **Reusability** - Use the same script across different projects
- **Consistency** - Maintain consistent structure within each configuration
- **Maintainability** - Change directory structure without modifying code
- **Team Collaboration** - Share configurations across teams
- **Multi-Organization Support** - Handle different client/org requirements

## JSON Configuration

For bulk operations, you can use a JSON configuration file to define multiple infrastructure components at once. This is especially useful for API servers or automated deployments.

### Configuration File Format

```json
{
  "description": "Infrastructure configuration",
  "version": "1.0",
  "environments": ["dev", "staging"],
  "global_resources": ["dev", "staging"],
  "regions": [
    {
      "name": "us-east-1",
      "environment": "dev"
    },
    {
      "name": "us-west-2",
      "environment": "staging"
    }
  ],
  "zones": [
    {
      "name": "z1a",
      "environment": "dev",
      "region": "us-east-1"
    }
  ],
  "projects": ["webapp", "api"]
}
```

### Configuration Sections

- **`environments`** - Array of environment names to create
- **`global_resources`** - Array of environment names for global resources
- **`regions`** - Array of region objects with `name` and `environment` fields
- **`zones`** - Array of zone objects with `name`, `environment`, and `region` fields
- **`projects`** - Array of project names to create

### Sample Configuration

See `admin/sample-infrastructure.json` for a complete example configuration.

### Benefits of JSON Configuration

- **Bulk Operations** - Create multiple components in a single command
- **Version Control** - Track infrastructure changes in Git
- **API Integration** - Perfect for automated deployments and CI/CD pipelines
- **Consistency** - Ensure all environments have the same structure
- **Documentation** - Self-documenting infrastructure as code
- **Reusability** - Share configurations across teams and projects

### Error Handling and Validation

The script validates the JSON configuration before processing:
- **Structure Validation** - Ensures all required fields are present
- **Type Validation** - Verifies arrays and objects are correctly formatted
- **Dependency Validation** - Ensures regions reference valid environments
- **Progress Tracking** - Shows success/failure counts for each component
- **Rollback Support** - Failed operations don't affect successful ones

## Template System

The script uses templates from `admin/templates/` to create new components:

- `admin/templates/env/` - Environment templates
- `admin/templates/global/` - Global resource templates
- `admin/templates/region/` - Regional resource templates
- `admin/templates/zone/` - Zone templates
- `admin/templates/project/` - Project templates

### Template Placeholders

Templates use placeholders that get replaced with actual values:

- `{{env_name}}` - Environment name
- `{{region_name}}` - Region name
- `{{zone_name}}` - Zone name
- `{{project_name}}` - Project name

## Directory Structure

The script creates components in this structure:

```
envs/
├── <environment>/
│   ├── env.hcl
│   ├── _global/
│   │   └── terragrunt.hcl
│   └── <project>/
│       ├── project.hcl
│       └── <region>/
│           ├── region.hcl
│           └── <zone>/
│               └── terragrunt.hcl
```

## Safety Features

- **Dry run mode** (`--dry-run`) shows what would happen without making changes
- **Force flag** (`-f`) required to overwrite existing components
- **Template validation** ensures required templates exist before creation
- **Path validation** prevents creation in invalid locations

## Dependencies

- Perl 5.10 or higher
- Required Perl modules:
  - `File::Path`
  - `File::Copy`
  - `File::Basename`
  - `File::Spec`
  - `Getopt::Long`
  - `Cwd`
  - `Data::Dumper`

## Troubleshooting

### Common Issues

1. **"Environment name required"** - Make sure to provide the environment name as a positional argument
2. **"Template not found"** - Ensure the required template directory exists in `admin/templates/`
3. **"Permission denied"** - Check file permissions in the target directory
4. **"Already exists"** - Use `-f` flag to force overwrite, or remove existing component first

### Debug Mode

Use `-v` flag for verbose output to see detailed information about what the script is doing.

### Dry Run

Always use `--dry-run` first to verify the script will do what you expect before making actual changes.
