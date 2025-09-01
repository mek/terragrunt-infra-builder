#!/usr/bin/env perl
#
# Terragrunt Infrastructure Management System
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use lib 'lib';
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Basename;
use File::Spec;
use File::Find;
use Getopt::Long;
use Cwd 'abs_path';
use Data::Dumper;
use JSON;
use YAML::Tiny;
use POSIX qw(strftime);
use Resource::Factory;
use Resource::Base;
use Infrastructure::Factory;
use Util::Color;

# Global variables
my $workspace_root;
my $template_dir;
my $verbose = 0;
my $dry_run = 0;
my $force = 0;
my $config_file = "config/manage-config.yaml";
my $config;
my $workspace_structure;

# Command line options
GetOptions(
    'verbose|v'       => \$verbose,
    'dry-run'         => \$dry_run,
    'force|f'         => \$force,
    'env|e=s'        => \my $env_opt,
    'project|p=s'     => \my $project_opt,
    'region|r=s'      => \my $region_opt,
    'zone|z=s'        => \my $zone_opt,
    'resource-type=s' => \my $resource_type,
    'resource-path=s' => \my $resource_path,
    'config|c=s'      => \my $json_config_file,
    'config-file=s'   => \my $config_file_override,
    'structure-order=s' => \my $structure_order,
    'generate-inputs' => \my $generate_inputs,
    'help|h'          => sub { print_help(); exit 0; }
) or die "Error in command line arguments\n";

# Main execution
sub main {
    # Initialize colors
    Util::Color::init_colors();
    
    print "${BOLD}${GREEN}Infrastructure Management Script${NC}\n";
    print "=" x 60 . "\n\n";
    
    # Find workspace root
    find_workspace_root();
    
    # Load configuration
    if ($config_file_override) {
        $config_file = $config_file_override;
    }
    load_configuration();
    
    # Validate workspace structure now that config is loaded
    validate_workspace_structure();
    
    # Normalize structure order (convert hyphens to underscores)
    if ($structure_order) {
        $structure_order =~ s/-/_/g;
    }
    
    # Validate and detect directory structure ordering
    $workspace_structure = validate_structure_consistency($structure_order);
    
    # Set template directory from config
    $template_dir = "$workspace_root/" . get_config_value("templates.base_path");
    
    # Check if we have arguments
    if (@ARGV < 1) {
        print_help();
        exit 1;
    }
    
    my $action = shift @ARGV;
    
    # Parse additional options and positional arguments
    my %options = parse_options(@ARGV);
    
    # Execute action
    if ($action eq 'add') {
        if ($json_config_file) {
            execute_add_from_config($json_config_file, %options);
        } else {
            # Need target for non-config operations
            if (@ARGV < 1) {
                print_help();
                exit 1;
            }
            my $target = shift @ARGV;
            execute_add($target, %options);
        }
    }
    elsif ($action eq 'list') {
        if (@ARGV < 1) {
            print_help();
            exit 1;
        }
        my $target = shift @ARGV;
        execute_list($target, %options);
    }
    elsif ($action eq 'remove') {
        if (@ARGV < 1) {
            print_help();
            exit 1;
        }
        my $target = shift @ARGV;
        execute_remove($target, %options);
    }
    elsif ($action eq 'show') {
        if (@ARGV < 1) {
            print_help();
            exit 1;
        }
        my $target = shift @ARGV;
        execute_show($target, %options);
    }
    elsif ($action eq 'zones') {
        list_available_zones();
    }
    else {
        print "${RED}Unknown action: $action${NC}\n";
        print_help();
        exit 1;
    }
}

sub print_help {
    print <<'HELP';
Infrastructure Management Script

Usage: ./manage.pl <ACTION> <TARGET> [OPTIONS]

Actions:
    add <target>     Add new infrastructure component
    list <target>    List existing infrastructure components
    remove <target>  Remove infrastructure component
    show <target>    Show details of infrastructure component
    zones            List all available zones with their short names

Targets:
    env <name>       Environment (dev, staging, prod)
    project <name>   Project (h2g2, etc.)
    region <name>    Regional resources (-e <env> required)
    zone <name>      Availability zone - must be from allowed zones list
                     (-e <env> -r <region> required, -p <project> required for project-based placement)
                     Use './manage.pl zones' to see available zones
    resource <name>  Add resource with custom name
                     Format: <name> (uses name as resource type)
                     Format: <name>:<type> (custom name with specific resource type)
                     Examples: db1:rds-mysql, cache1:redis, web-sg:security-group

Options:
    -e, --env <env>      Environment name
    -p, --project <proj> Project name
    -r, --region <reg>   Region name
    -z, --zone <zone>    Zone name
    --resource-type <type> Resource type (eks, vpc, rds, etc.)
    --resource-path <path> Full path for resource placement
    -c, --config <file>  JSON configuration file for bulk operations
    --config-file <file> Script configuration file (default: config/manage-config.yaml)
    -v, --verbose        Verbose output
    --dry-run            Show what would be done without executing
    -f, --force          Force overwrite of existing files
    --generate-inputs    Generate inputs.json file from terraform module analysis
    -h, --help           Show this help message

Examples:
    # List available zones and resource types
    ./manage.pl zones
    ./manage.pl list resources
    
    # Add new environment
    ./manage.pl add env "staging"
    
    # Add availability zone (must be from allowed zones list)
    ./manage.pl add zone "us-east-1" -e dev -r "us-east-1"
    
    # Add resource instances with custom names (NEW!)
    # Format: name:type for custom naming
    ./manage.pl add resource "db1:rds-mysql" -e testing -r us-west-2
    ./manage.pl add resource "db2:rds-postgres" -e testing -r us-west-2  
    ./manage.pl add resource "cache1:redis" -e testing -r us-west-2
    ./manage.pl add resource "web-sg:security-group" -e testing -r us-west-2
    
    # Multiple instances of the same type using aliases
    ./manage.pl add resource "primary-db:mysql" -e prod -r us-east-1
    ./manage.pl add resource "analytics-db:postgres" -e prod -r us-east-1
    
    # Traditional method (backward compatible)
    ./manage.pl add resource "vpc" -e testing -r us-west-2
    ./manage.pl add resource "eks" -e testing -r us-west-2 -z us-east-1
    
    # Environment and regional resource examples
    ./manage.pl add resource "iam-roles" -e dev
    ./manage.pl add resource "route53-zone" -e dev
    
    # Add multiple components from JSON config
    ./manage.pl add --config infrastructure.json
    
    # List all environments
    ./manage.pl list env
    
    # List available resource types
    ./manage.pl list resources
    
    # Show environment details
    ./manage.pl show env "dev"

HELP
}

sub load_configuration {
    # Load configuration file
    if (-f $config_file) {
        eval {
            $config = YAML::Tiny->read($config_file);
            $config = $config->[0];  # YAML::Tiny returns array reference
        };
        if ($@) {
            die "${RED}Error loading configuration file: $@${NC}\n";
        }
        print "${GREEN}Configuration loaded from: $config_file${NC}\n" if $verbose;
    } else {
        # Use default configuration
        $config = {
            directories => {
                environments => "envs",
                projects => "projects",
                modules => "modules",
                environment_structure => {
                    regional_placement => "direct",
                    default_project => "h2g2",
                }
            },
            templates => {
                base_path => "templates",
                environment => "env",
                region => "region",
                zone => "zone",
                project => "project"
            },
            files => {
                environment => "env.hcl",
                region => "region.hcl",
                project => "project.hcl",
                terragrunt => "terragrunt.hcl"
            },
            zones => {
                allowed => {
                    "us-east-1" => "ohio",
                    "us-west-2" => "oregon",
                    "us-west-1" => "california",
                    "eu-west-1" => "ireland",
                    "eu-central-1" => "frankfurt",
                    "ap-southeast-1" => "singapore",
                    "ap-northeast-1" => "tokyo"
                }
            }
        };
        print "${YELLOW}Using default configuration (no config file found)${NC}\n" if $verbose;
    }
}

sub get_config_value {
    my ($path) = @_;
    my @keys = split(/\./, $path);
    my $value = $config;
    
    foreach my $key (@keys) {
        return undef unless defined $value && ref($value) eq 'HASH';
        $value = $value->{$key};
    }
    
    return $value;
}

sub validate_workspace_structure {
    my $envs_dir = "$workspace_root/" . get_config_value("directories.environments");
    if (!-d $envs_dir) {
        warn "${YELLOW}Warning: Environments directory not found: $envs_dir${NC}\n" if $verbose;
    }
}

sub find_workspace_root {
    my $current_dir = abs_path('.');
    
    # Look for terragrunt.hcl in current directory or parents
    my $dir = $current_dir;
    while ($dir ne '/') {
        if (-f "$dir/terragrunt.hcl") {
            $workspace_root = $dir;
            last;
        }
        $dir = dirname($dir);
    }
    
    if (!$workspace_root) {
        die "${RED}Error: Could not find workspace root (no terragrunt.hcl found)${NC}\n";
    }
    
    # Note: Workspace structure validation moved to after config loading
    
    print "${GREEN}Workspace root: $workspace_root${NC}\n" if $verbose;
}

sub detect_workspace_structure {
    my $lock_file = "$workspace_root/.terragrunt-structure.lock";
    
    # Check if structure is already locked
    if (-f $lock_file) {
        return read_structure_lock($lock_file);
    }
    
    # Auto-detect based on existing directories
    my $envs_base = get_config_value("directories.environments");
    my $projects_base = get_config_value("directories.projects");
    my $has_envs = -d "$workspace_root/$envs_base" && directory_has_content("$workspace_root/$envs_base");
    my $has_projects = -d "$workspace_root/$projects_base" && directory_has_content("$workspace_root/$projects_base");
    
    my $detected_order;
    if ($has_envs && !$has_projects) {
        $detected_order = "environment_first";
        print "${CYAN}Auto-detected structure: environment_first ($envs_base/ directory found)${NC}\n" if $verbose;
    } elsif ($has_projects && !$has_envs) {
        $detected_order = "project_first";
        print "${CYAN}Auto-detected structure: project_first ($projects_base/ directory found)${NC}\n" if $verbose;
    } elsif (!$has_envs && !$has_projects) {
        # New workspace - use config default or flag
        $detected_order = $structure_order || get_config_value("directories.structure_ordering") || "environment_first";
        print "${CYAN}New workspace - using structure: $detected_order${NC}\n" if $verbose;
    } else {
        # Both exist - this is a problem!
        die "${RED}ERROR: Both '$envs_base/' and '$projects_base/' directories exist with content. Please clean up or manually set structure lock.${NC}\n";
    }
    
    # Write lock file
    write_structure_lock($lock_file, $detected_order);
    return $detected_order;
}

sub directory_has_content {
    my $dir = shift;
    return 0 unless -d $dir;
    
    opendir(my $dh, $dir) or return 0;
    my @entries = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir($dh);
    
    return scalar(@entries) > 0;
}

sub read_structure_lock {
    my $lock_file = shift;
    
    open my $fh, '<', $lock_file or die "Cannot read structure lock file $lock_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    my $lock_data = eval { decode_json($content) };
    if ($@) {
        die "${RED}ERROR: Invalid structure lock file format: $@${NC}\n";
    }
    
    return $lock_data->{structure_ordering};
}

sub write_structure_lock {
    my ($lock_file, $structure_order) = @_;
    
    my $timestamp = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime;
    
    my $envs_base = get_config_value("directories.environments");
    my $projects_base = get_config_value("directories.projects");
    
    my $lock_data = {
        structure_ordering => $structure_order,
        created_timestamp => $timestamp,
        last_verified => $timestamp,
        detected_patterns => {
            has_envs_dir => (-d "$workspace_root/$envs_base") ? JSON::true : JSON::false,
            has_projects_dir => (-d "$workspace_root/$projects_base") ? JSON::true : JSON::false,
        }
    };
    
    open my $fh, '>', $lock_file or die "Cannot write structure lock file $lock_file: $!";
    print $fh JSON->new->pretty->encode($lock_data);
    close $fh;
    
    print "${GREEN}Created structure lock file: $structure_order${NC}\n" if $verbose;
}

sub validate_structure_consistency {
    my ($requested_order) = @_;
    my $current_structure = detect_workspace_structure();
    
    # Normalize both values for comparison (convert hyphens to underscores)
    my $normalized_requested = $requested_order;
    my $normalized_current = $current_structure;
    if ($normalized_requested) {
        $normalized_requested =~ s/-/_/g;
    }
    if ($normalized_current) {
        $normalized_current =~ s/-/_/g;
    }
    
    if ($requested_order && $normalized_requested ne $normalized_current) {
        print "${RED}ERROR: Structure mismatch!${NC}\n";
        print "  Current workspace structure: ${YELLOW}$current_structure${NC}\n";
        print "  Requested structure: ${YELLOW}$requested_order${NC}\n";
        print "  Use --force to override (not recommended)\n\n";
        
        if (!$force) {
            print "To fix this:\n";
            print "  1. Remove --structure-order flag to use current structure\n";
            print "  2. Or use --force to override (may cause inconsistencies)\n";
            print "  3. Or migrate structure using: manage.pl migrate-structure\n";
            exit 1;
        } else {
            print "${YELLOW}WARNING: Forcing structure override. This may cause inconsistencies.${NC}\n";
        }
    }
    
    return $normalized_current;
}

sub parse_options {
    my %options;
    
    $options{env} = $env_opt if defined $env_opt;
    $options{project} = $project_opt if defined $project_opt;
    $options{region} = $region_opt if defined $region_opt;
    $options{zone} = $zone_opt if defined $zone_opt;
    $options{resource_type} = $resource_type if defined $resource_type;
    $options{resource_path} = $resource_path if defined $resource_path;
    
    return %options;
}

sub parse_resource_specification {
    my ($resource_spec) = @_;
    
    # Check if specification contains type separator (:)
    if ($resource_spec =~ /^([^:]+):(.+)$/) {
        my ($name, $type) = ($1, $2);
        
        # Validate the resource type
        my %supported_types = Resource::Factory::get_supported_resource_types();
        if (exists $supported_types{$type}) {
            my $canonical_type = $supported_types{$type};
            print "${CYAN}Creating resource '$name' of type '$canonical_type'${NC}\n" if $verbose;
            if ($type ne $canonical_type) {
                print "${YELLOW}  (resolved from alias: $type)${NC}\n" if $verbose;
            }
            return ($name, $canonical_type);
        } else {
            # Show suggestions for invalid types
            my @suggestions = Resource::Factory::suggest_resource_types($type);
            print "${RED}Error: Unknown resource type '$type'${NC}\n";
            if (@suggestions) {
                print "${YELLOW}Did you mean one of these?${NC}\n";
                foreach my $suggestion (@suggestions) {
                    print "  - $suggestion\n";
                }
            }
            exit 1;
        }
    } else {
        # No type specified, use the name as both name and type
        # This preserves backward compatibility
        return ($resource_spec, undef);
    }
}

sub execute_add {
    my $target = shift;
    my %options = @_;
    
    if ($target eq 'env') {
        # For env, the name comes from the first remaining argument
        my $env_name = shift @ARGV;
        die "Environment name required" unless $env_name;
        add_environment($env_name, $project_opt);
    }
    elsif ($target eq 'project') {
        # For project, the name comes from the first remaining argument
        my $project_name = shift @ARGV;
        die "Project name required" unless $project_name;
        add_project($project_name);
    }
    elsif ($target eq 'region') {
        # For region, the name comes from the first remaining argument
        my $region_name = shift @ARGV;
        die "Region name required" unless $region_name;
        die "Environment (-e) required for regional resources" unless $options{env};
        add_regional_resources($region_name, $options{env}, $options{project});
    }
    elsif ($target eq 'zone') {
        # For zone, the name comes from the first remaining argument
        my $zone_name = shift @ARGV;
        die "Zone name required" unless $zone_name;
        die "Environment (-e) and region (-r) required for zone" unless $options{env} && $options{region};
        add_zone($zone_name, $options{env}, $options{region}, $options{project});
    }
    elsif ($target eq 'resource') {
        # For resource, the name/path comes from the first remaining argument
        my $resource_spec = shift @ARGV;
        die "Resource specification required" unless $resource_spec;
        die "Environment (-e) required for resource" unless $options{env};
        
        # Parse resource specification: name:type or just name
        my ($resource_name, $resource_type) = parse_resource_specification($resource_spec);
        $options{resource_type} = $resource_type if $resource_type;
        
        add_resource($resource_name, %options);
    }
    else {
        print "${RED}Unknown target: $target${NC}\n";
        print_help();
        exit 1;
    }
}

sub add_environment {
    my ($env_name, $project_name) = @_;
    
    print "${CYAN}Adding environment: $env_name${NC}\n";
    
    if ($verbose) {
        print "  Structure ordering: $workspace_structure\n";
        print "  Project name: " . ($project_name || "none") . "\n";
    }
    
    # Create environment using Infrastructure module
    my $env;
    eval {
        $env = Infrastructure::Factory->create_infrastructure(
            type => 'environment',
            name => $env_name,
            project_name => $project_name,
            workspace_root => $workspace_root,
            template_dir => $template_dir,
            envs_base => get_config_value("directories.environments"),
            projects_base => get_config_value("directories.projects"),
            structure_ordering => $workspace_structure,
            dry_run => $dry_run,
            verbose => $verbose,
            force => $force,
        );
    };
    
    if ($@) {
        print "${RED}Error creating environment: $@${NC}\n";
        return 0;
    }
    
    # Validate and create
    eval {
        $env->validate();
        $env->create();
    };
    
    if ($@) {
        print "${RED}Error: $@${NC}\n";
        return 0;
    }
    
    return 1;
}

sub add_project {
    my $project_name = shift;
    
    print "${CYAN}Adding project: $project_name${NC}\n";
    
    # Create project using Infrastructure module
    my $project;
    eval {
        $project = Infrastructure::Factory->create_infrastructure(
            type => 'project',
            name => $project_name,
            workspace_root => $workspace_root,
            template_dir => $template_dir,
            dry_run => $dry_run,
            verbose => $verbose,
            force => $force,
        );
    };
    
    if ($@) {
        print "${RED}Error creating project: $@${NC}\n";
        return 0;
    }
    
    # Validate and create
    eval {
        $project->validate();
        $project->create();
    };
    
    if ($@) {
        print "${RED}Error: $@${NC}\n";
        return 0;
    }
    
    return 1;
}

# Removed add_global_resources - use add_resource at env level instead

sub add_regional_resources {
    my $region_name = shift;
    my $env_name = shift;
    my $project_name = shift;  # Optional project parameter
    
    if ($project_name) {
        print "${CYAN}Adding regional resources: $region_name for environment: $env_name, project: $project_name${NC}\n";
    } else {
        print "${CYAN}Adding regional resources: $region_name for environment: $env_name${NC}\n";
    }
    
    # Create region using Infrastructure module
    my $region;
    eval {
        $region = Infrastructure::Factory->create_infrastructure(
            type => 'region',
            name => $region_name,
            env_name => $env_name,
            project_name => $project_name,
            workspace_root => $workspace_root,
            template_dir => $template_dir,
            dry_run => $dry_run,
            verbose => $verbose,
            force => $force,
        );
    };
    
    if ($@) {
        print "${RED}Error creating region: $@${NC}\n";
        return 0;
    }
    
    # Validate and create
    eval {
        $region->validate();
        $region->create();
    };
    
    if ($@) {
        print "${RED}Error: $@${NC}\n";
        return 0;
    }
    
    return 1;
}

sub add_zone {
    my $zone_name = shift;
    my $env_name = shift;
    my $region_name = shift;
    my $project_name = shift;
    
    # Validate zone against allowed zones
    my $allowed_zones = get_config_value("zones.allowed");
    if (!$allowed_zones || !exists $allowed_zones->{$zone_name}) {
        my @valid_zones = $allowed_zones ? sort keys %$allowed_zones : ();
        print "${RED}Error: Zone '$zone_name' is not in the list of allowed zones${NC}\n";
        if (@valid_zones) {
            print "${YELLOW}Allowed zones:${NC}\n";
            foreach my $zone (sort keys %$allowed_zones) {
                print "  - $zone ($allowed_zones->{$zone})\n";
            }
        }
        return 0;
    }
    
    my $zone_short_name = $allowed_zones->{$zone_name};
    print "${CYAN}Adding zone: $zone_name ($zone_short_name) in region: $region_name for environment: $env_name${NC}\n";
    
    # Create zone using Infrastructure module
    my $zone;
    eval {
        $zone = Infrastructure::Factory->create_infrastructure(
            type => 'zone',
            name => $zone_name,
            env_name => $env_name,
            region_name => $region_name,
            project_name => $project_name,
            workspace_root => $workspace_root,
            template_dir => $template_dir,
            dry_run => $dry_run,
            verbose => $verbose,
            force => $force,
        );
    };
    
    if ($@) {
        print "${RED}Error creating zone: $@${NC}\n";
        return 0;
    }
    
    # Validate and create
    eval {
        $zone->validate();
        $zone->create();
    };
    
    if ($@) {
        print "${RED}Error: $@${NC}\n";
        return 0;
    }
    
    return 1;
}

sub add_resource {
    my $resource_name = shift;
    my %options = @_;
    
    print "${CYAN}Adding resource: $resource_name${NC}\n";
    
    if ($verbose) {
        print "  Options received:\n";
        print "    env: $options{env}\n" if $options{env};
        print "    region: $options{region}\n" if $options{region};
        print "    zone: $options{zone}\n" if $options{zone};
        print "    project: $options{project}\n" if $options{project};
    }
    
    # Handle project-based placement
    if (!$options{project} && get_config_value("directories.environment_structure.regional_placement") eq "project_based") {
        $options{project} = get_config_value("directories.environment_structure.default_project");
    }
    
    # Create resource using factory
    my $resource;
    eval {
        $resource = Resource::Factory->create_resource(
            name               => $resource_name,
            env_name           => $options{env},
            region_name        => $options{region},
            zone_name          => $options{zone},
            project_name       => $options{project},
            resource_type      => $options{resource_type},
            workspace_root     => $workspace_root,
            template_dir       => $template_dir,
            envs_base          => get_config_value("directories.environments"),
            projects_base      => get_config_value("directories.projects"),
            structure_ordering => $workspace_structure,
            dry_run            => $dry_run,
            verbose            => $verbose,
            force              => $force,
            generate_inputs    => $generate_inputs,
        );
    };
    
    if ($@) {
        print "${RED}Error creating resource: $@${NC}\n";
        return 0;
    }
    
    # Validate resource configuration
    eval {
        $resource->validate();
    };
    
    if ($@) {
        print "${RED}Validation failed: $@${NC}\n";
        return 0;
    }
    
    # Create the resource
    my $result = $resource->create();
    
    if ($result) {
        print "${GREEN}✓ Resource $resource_name created successfully${NC}\n";
    } else {
        print "${RED}Failed to create resource $resource_name${NC}\n";
    }
    
    return $result;
}

# These functions are now handled by the Resource modules
# Keeping for backward compatibility if needed

sub list_available_resource_types {
    return Resource::Factory::list_resource_types($template_dir);
}

# Enhanced terragrunt configuration generator
sub create_resource_terragrunt {
    my ($resource_dir, $resource_name, $resource_type, 
        $env_name, $region_name, $zone_name, $hierarchy_level) = @_;
    
    my $terragrunt_file = "$resource_dir/terragrunt.hcl";
    
    # Skip if file already exists (from template)
    return if -f $terragrunt_file;
    
    # Build context for template generation
    my $context = {
        resource_name => $resource_name,
        resource_type => $resource_type,
        env_name => $env_name,
        region_name => $region_name,
        zone_name => $zone_name,
        hierarchy_level => $hierarchy_level,
        allowed_zones => get_config_value("zones.allowed"),
    };
    
    my $content = generate_terragrunt_content($context);
    
    # Write the file
    if (!$dry_run) {
        open(my $fh, '>', $terragrunt_file) or die "Cannot write $terragrunt_file: $!";
        print $fh $content;
        close $fh;
        
        print "  Created terragrunt.hcl for $resource_name\n" if $verbose;
    } else {
        print "  [DRY RUN] Would create terragrunt.hcl for $resource_name\n";
    }
}

sub generate_terragrunt_content {
    my ($context) = @_;
    
    my @lines;
    
    # Header with metadata
    push @lines, generate_terragrunt_header($context);
    
    # Include blocks
    push @lines, generate_terragrunt_includes($context);
    
    # Locals block
    push @lines, generate_terragrunt_locals($context);
    
    # Terraform source configuration
    push @lines, generate_terragrunt_terraform($context);
    
    # Inputs block
    push @lines, generate_terragrunt_inputs($context);
    
    return join("\n", @lines) . "\n";
}

sub generate_terragrunt_header {
    my ($context) = @_;
    
    my $zone_info = "";
    if ($context->{zone_name} && $context->{allowed_zones}) {
        my $zone_short = $context->{allowed_zones}->{$context->{zone_name}} || "unknown";
        $zone_info = " ($zone_short)";
    }
    
    return join("\n",
        "# Terragrunt configuration for $context->{resource_name}",
        "# Resource type: $context->{resource_type}",
        "# Environment: $context->{env_name}",
        "# Region: " . ($context->{region_name} || "global"),
        "# Zone: " . ($context->{zone_name} ? "$context->{zone_name}$zone_info" : "N/A"),
        "# Generated: " . strftime("%Y-%m-%d %H:%M:%S", localtime),
        ""
    );
}

sub generate_terragrunt_includes {
    my ($context) = @_;
    
    my @includes = (
        'include "root" {',
        '  path = find_in_parent_folders()',
        '}',
        '',
        'include "env" {',
        '  path = find_in_parent_folders("env.hcl")',
        '}'
    );
    
    if ($context->{region_name}) {
        push @includes, (
            '',
            'include "region" {',
            '  path = find_in_parent_folders("region.hcl")',
            '}'
        );
    }
    
    push @includes, '';
    return join("\n", @includes);
}

sub generate_terragrunt_locals {
    my ($context) = @_;
    
    my @locals = (
        'locals {',
        '  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))'
    );
    
    if ($context->{region_name}) {
        push @locals, '  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))';
    }
    
    push @locals, (
        '  ',
        '  environment = local.env_vars.locals.environment'
    );
    
    if ($context->{region_name}) {
        push @locals, '  aws_region = local.region_vars.locals.aws_region';
    }
    
    if ($context->{zone_name}) {
        push @locals, "  zone = \"$context->{zone_name}\"";
        if ($context->{allowed_zones} && $context->{allowed_zones}->{$context->{zone_name}}) {
            push @locals, "  zone_short = \"$context->{allowed_zones}->{$context->{zone_name}}\"";
        }
    }
    
    push @locals, ('}', '');
    return join("\n", @locals);
}

sub generate_terragrunt_terraform {
    my ($context) = @_;
    
    my $resource_type = $context->{resource_type};
    
    return join("\n",
        'terraform {',
        "  # Source options for $resource_type:",
        "  # source = \"tfr:///terraform-aws-modules/$resource_type/aws\"",
        "  # source = \"git::https://github.com/terraform-aws-modules/terraform-aws-$resource_type.git\"",
        "  # source = \"../../modules/$resource_type\"",
        "  ",
        "  # TODO: Uncomment and configure the appropriate source",
        '}',
        ''
    );
}

sub generate_terragrunt_inputs {
    my ($context) = @_;
    
    my @name_parts = ('${local.environment}');
    push @name_parts, '${local.aws_region}' if $context->{region_name};
    push @name_parts, '${local.zone}' if $context->{zone_name};
    push @name_parts, $context->{resource_name};
    
    my $name_template = join('-', @name_parts);
    
    my @inputs = (
        'inputs = {',
        '  # Standard naming convention',
        "  name = \"$name_template\"",
        '  ',
        '  # Common tags applied to all resources',
        '  tags = {',
        '    Environment = local.environment',
        '    ManagedBy   = "Terragrunt"',
        "    Resource    = \"$context->{resource_name}\"",
        "    Type        = \"$context->{resource_type}\""
    );
    
    if ($context->{region_name}) {
        push @inputs, '    Region      = local.aws_region';
    }
    
    if ($context->{zone_name}) {
        push @inputs, '    Zone        = local.zone';
        if ($context->{allowed_zones} && $context->{allowed_zones}->{$context->{zone_name}}) {
            push @inputs, "    ZoneShort   = \"$context->{allowed_zones}->{$context->{zone_name}}\"";
        }
    }
    
    push @inputs, (
        '  }',
        '  ',
        "  # TODO: Add $context->{resource_type}-specific configuration here",
        '  # Refer to inputs.json for available variables',
        '}'
    );
    
    return join("\n", @inputs);
}

sub copy_directory {
    my $source = shift;
    my $dest = shift;
    
    print "  Copying from: $source\n" if $verbose;
    
    # Use system cp for recursive copy
    my $cp_cmd = "cp -r '$source'/* '$dest'";
    
    if ($dry_run) {
        print "    [DRY RUN] Would run: $cp_cmd\n";
    } else {
        my $result = system($cp_cmd);
        if ($result != 0) {
            die "${RED}Error copying directory: $source to $dest${NC}\n";
        }
    }
}

sub update_environment_files {
    my $env_dir = shift;
    my $env_name = shift;
    
    print "  Updating environment files for: $env_name\n" if $verbose;
    
    # Update env.hcl file
    my $env_file = "$env_dir/env.hcl";
    if (-f $env_file) {
        update_file_content($env_file, 'env_name', $env_name);
    }
    
    # Update other environment-specific files
    update_file_content("$env_dir/terragrunt.hcl", 'env_name', $env_name) if -f "$env_dir/terragrunt.hcl";
}

sub update_project_files {
    my $project_dir = shift;
    my $project_name = shift;
    
    print "  Updating project files for: $project_name\n" if $verbose;
    
    # Update project.hcl file
    my $project_file = "$project_dir/project.hcl";
    if (-f $project_file) {
        update_file_content($project_file, 'project_name', $project_name);
    }
}

# Removed update_global_files - no longer using _global directories

sub update_region_files {
    my $region_dir = shift;
    my $region_name = shift;
    my $env_name = shift;
    
    print "  Updating region files for: $region_name in $env_name\n" if $verbose;
    
    # Update region.hcl file
    my $region_file = "$region_dir/region.hcl";
    if (-f $region_file) {
        update_file_content($region_file, 'region_name', $region_name);
        update_file_content($region_file, 'env_name', $env_name);
    }
    
    # Update other region-specific files
    update_file_content("$region_dir/terragrunt.hcl", 'region_name', $region_name) if -f "$region_dir/terragrunt.hcl";
    update_file_content("$region_dir/terragrunt.hcl", 'env_name', $env_name) if -f "$region_dir/terragrunt.hcl";
}

sub update_zone_files {
    my $zone_dir = shift;
    my $zone_name = shift;
    my $region_name = shift;
    my $env_name = shift;
    
    print "  Updating zone files for: $zone_name in $region_name/$env_name\n" if $verbose;
    
    # Update zone-specific files
    update_file_content("$zone_dir/terragrunt.hcl", 'zone_name', $zone_name) if -f "$zone_dir/terragrunt.hcl";
    update_file_content("$zone_dir/terragrunt.hcl", 'region_name', $region_name) if -f "$zone_dir/terragrunt.hcl";
    update_file_content("$zone_dir/terragrunt.hcl", 'env_name', $env_name) if -f "$zone_dir/terragrunt.hcl";
}

sub update_file_content {
    my $file_path = shift;
    my $placeholder = shift;
    my $value = shift;
    
    print "    Updating $file_path: $placeholder -> $value\n" if $verbose;
    
    if ($dry_run) {
        print "      [DRY RUN] Would update $file_path\n";
        return;
    }
    
    # Read file content
    open(my $read_fh, '<', $file_path) or die "Cannot read $file_path: $!";
    my $content = do { local $/; <$read_fh> };
    close $read_fh;
    
    # Replace placeholder
    $content =~ s/\{\{$placeholder\}\}/$value/g;
    
    # Write updated content
    open(my $write_fh, '>', $file_path) or die "Cannot write $file_path: $!";
    print $write_fh $content;
    close $write_fh;
}

sub execute_list {
    my $target = shift;
    my %options = @_;
    
    if ($target eq 'env') {
        list_environments();
    }
    elsif ($target eq 'project') {
        list_projects();
    }
    elsif ($target eq 'region') {
        die "Environment (-e) required" unless $options{env};
        list_regions($options{env});
    }
    elsif ($target eq 'zone') {
        die "Environment (-e) and region (-r) required" unless $options{env} && $options{region};
        list_zones($options{env}, $options{region}, %options);
    }
    elsif ($target eq 'resources' || $target eq 'resource') {
        list_resource_types();
    }
    else {
        print "${RED}Unknown target: $target${NC}\n";
        print_help();
        exit 1;
    }
}

sub list_environments {
    print "${CYAN}Environments:${NC}\n";
    
    my $envs_base = get_config_value("directories.environments");
    my $envs_dir = "$workspace_root/$envs_base";
    return unless -d $envs_dir;
    
    my @envs = glob("$envs_dir/*");
    @envs = grep { -d $_ } @envs;
    @envs = map { basename($_) } @envs;
    
    if (@envs) {
        foreach my $env (sort @envs) {
            print "  - $env\n";
        }
    } else {
        print "  No environments found\n";
    }
}

sub list_projects {
    print "${CYAN}Projects:${NC}\n";
    
    my $projects_base = get_config_value("directories.projects");
    my $projects_dir = "$workspace_root/$projects_base";
    return unless -d $projects_dir;
    
    my @projects = glob("$projects_dir/*");
    @projects = grep { -d $_ } @projects;
    @projects = map { basename($_) } @projects;
    
    if (@projects) {
        foreach my $project (sort @projects) {
            print "  - $project\n";
        }
    } else {
        print "  No projects found\n";
    }
}

sub list_regions {
    my $env_name = shift;
    
    print "${CYAN}Regions in environment '$env_name':${NC}\n";
    
    my $envs_base = get_config_value("directories.environments");
    my $env_dir = "$workspace_root/$envs_base/$env_name";
    return unless -d $env_dir;
    
    my $regional_placement = get_config_value("directories.environment_structure.regional_placement");
    my $global_dir_name = get_config_value("directories.environment_structure.global") || '__global';
    my $region_file = get_config_value("files.region");
    
    # Look for regions based on configuration
    my @regions;
    
    if ($regional_placement eq "project_based") {
        # Look for regions in project subdirectories
        my @projects = glob("$env_dir/*");
        @projects = grep { -d $_ } @projects;
        
        foreach my $project_dir (@projects) {
            my $project_name = basename($project_dir);
            next if $project_name eq $global_dir_name;
            
            my @project_regions = glob("$project_dir/*");
            @project_regions = grep { -d $_ } @project_regions;
            @project_regions = grep { basename($_) ne $global_dir_name } @project_regions;
            
            foreach my $region_dir (@project_regions) {
                my $region_name = basename($region_dir);
                # Check if it's actually a region by looking for region.hcl
                if (-f "$region_dir/$region_file") {
                    push @regions, "$project_name/$region_name";
                }
            }
        }
    } else {
        # Look for regions directly under environment
        my @direct_regions = glob("$env_dir/*");
        @direct_regions = grep { -d $_ } @direct_regions;
        @direct_regions = grep { basename($_) ne $global_dir_name } @direct_regions;
        
        foreach my $region_dir (@direct_regions) {
            my $region_name = basename($region_dir);
            # Check if it's actually a region by looking for region.hcl
            if (-f "$region_dir/$region_file") {
                push @regions, $region_name;
            }
        }
    }
    
    if (@regions) {
        foreach my $region (sort @regions) {
            print "  - $region\n";
        }
    } else {
        print "  No regions found\n";
    }
}

sub list_zones {
    my $env_name = shift;
    my $region_name = shift;
    my %options = @_;
    
    print "${CYAN}Zones in region '$region_name' of environment '$env_name':${NC}\n";
    
    my $envs_base = get_config_value("directories.environments");
    my $regional_placement = get_config_value("directories.environment_structure.regional_placement");
    my $regional_dir_name = get_config_value("directories.environment_structure.regional");
    
    # Determine the region directory based on configuration and options
    my $region_dir;
    if ($regional_placement eq "project_based") {
        # For project-based placement, we need the project name
        if ($options{project}) {
            # Use the project from options (-p flag)
            $region_dir = "$workspace_root/$envs_base/$env_name/$options{project}/$region_name";
        } else {
            # Fallback: try to extract project from region name if it contains /
            if ($region_name =~ /(.+)\/(.+)/) {
                my ($project, $region) = ($1, $2);
                $region_dir = "$workspace_root/$envs_base/$env_name/$project/$region";
            } else {
                # No project specified and no / in region name, can't determine path
                print "  ${RED}Error: Project (-p) required for project-based regional placement${NC}\n";
                return;
            }
        }
    } else {
        # Direct placement
        $region_dir = "$workspace_root/$envs_base/$env_name/$region_name";
    }
    
    return unless -d $region_dir;
    
    my @zones = glob("$region_dir/*");
    @zones = grep { -d $_ } @zones;
    @zones = grep { basename($_) ne $regional_dir_name } @zones;
    @zones = map { basename($_) } @zones;
    
    if (@zones) {
        foreach my $zone (sort @zones) {
            print "  - $zone\n";
        }
    } else {
        print "  No zones found\n";
    }
}

sub list_resource_types {
    print "${CYAN}Available AWS Resource Types:${NC}\n";
    print "=" x 40 . "\n";
    
    # Get available template types
    my @template_types = Resource::Factory::list_resource_types($template_dir);
    my %has_template = map { $_ => 1 } @template_types;
    
    # Get all supported types by category
    my %categories = Resource::Factory::get_resource_types_by_category();
    
    foreach my $category (sort keys %categories) {
        print "\n${BOLD}" . ucfirst($category) . ":${NC}\n";
        
        my $resources = $categories{$category};
        foreach my $resource (sort @$resources) {
            my $status = "";
            if ($has_template{$resource}) {
                $status = " ${GREEN}[template available]${NC}";
            } else {
                $status = " ${YELLOW}[template needed]${NC}";
            }
            
            print "  - $resource$status\n";
        }
    }
    
    # Show aliases
    print "\n${CYAN}Common Aliases:${NC}\n";
    my %type_map = Resource::Factory::get_supported_resource_types();
    my %aliases;
    
    foreach my $alias (sort keys %type_map) {
        my $canonical = $type_map{$alias};
        if ($alias ne $canonical) {
            push @{$aliases{$canonical}}, $alias;
        }
    }
    
    foreach my $canonical (sort keys %aliases) {
        print "  $canonical: " . join(', ', sort @{$aliases{$canonical}}) . "\n";
    }
    
    print "\n${YELLOW}Note:${NC}\n";
    print "- ${GREEN}Green${NC} resources have templates available\n";
    print "- ${YELLOW}Yellow${NC} resources need templates created\n";
    print "- Use aliases for convenience (e.g., 'sg' for 'security-group')\n";
}

sub list_available_zones {
    print "${CYAN}Available zones:${NC}\n";
    
    my $allowed_zones = get_config_value("zones.allowed");
    if (!$allowed_zones) {
        print "${RED}No zones configuration found${NC}\n";
        return;
    }
    
    if (%$allowed_zones) {
        my $max_zone_length = 0;
        foreach my $zone (keys %$allowed_zones) {
            $max_zone_length = length($zone) if length($zone) > $max_zone_length;
        }
        
        foreach my $zone (sort keys %$allowed_zones) {
            my $short_name = $allowed_zones->{$zone};
            printf "  %-${max_zone_length}s  %s\n", $zone, $short_name;
        }
        
        print "\n${YELLOW}Usage: ./manage.pl add zone <zone_name> -e <env> -r <region>${NC}\n";
    } else {
        print "${YELLOW}No zones configured${NC}\n";
    }
}

sub execute_remove {
    my $target = shift;
    my %options = @_;
    
    print "${RED}Remove functionality not yet implemented${NC}\n";
    print "This would remove infrastructure components and their files.\n";
}

sub execute_show {
    my $target = shift;
    my %options = @_;
    
    print "${CYAN}Show functionality not yet implemented${NC}\n";
    print "This would show detailed information about infrastructure components.\n";
}

sub execute_add_from_config {
    my $config_file = shift;
    my %options = @_;
    
    print "${CYAN}Adding infrastructure components from config file: $config_file${NC}\n";
    
    # Read and parse JSON config
    my $config = read_json_config($config_file);
    
    # Validate config structure
    validate_config($config);
    
    # Process each component
    my $total_components = 0;
    my $successful_components = 0;
    
    # Process environments first
    if ($config->{environments}) {
        foreach my $env (@{$config->{environments}}) {
            $total_components++;
            print "\n${BLUE}Processing environment: $env${NC}\n";
            if (add_environment($env)) {
                $successful_components++;
            }
        }
    }
    
    # Process global resources (deprecated - use environment-level resources instead)
    if ($config->{global_resources}) {
        warn "${YELLOW}Warning: global_resources is deprecated. Use environment-level resources instead.${NC}\n";
        foreach my $global (@{$config->{global_resources}}) {
            $total_components++;
            print "\n${BLUE}Skipping deprecated global resources for environment: $global${NC}\n";
            # Skip deprecated functionality - count as successful for backward compatibility
            $successful_components++;
        }
    }
    
    # Process regions
    if ($config->{regions}) {
        foreach my $region_config (@{$config->{regions}}) {
            $total_components++;
            my $region_name = $region_config->{name};
            my $env_name = $region_config->{environment};
            my $project_name = $region_config->{project};  # Optional project from config
            print "\n${BLUE}Processing region: $region_name for environment: $env_name${NC}\n";
            if (add_regional_resources($region_name, $env_name, $project_name)) {
                $successful_components++;
            }
        }
    }
    
    # Process zones
    if ($config->{zones}) {
        foreach my $zone_config (@{$config->{zones}}) {
            $total_components++;
            my $zone_name = $zone_config->{name};
            my $env_name = $zone_config->{environment};
            my $region_name = $zone_config->{region};
            print "\n${BLUE}Processing zone: $zone_name in region: $region_name for environment: $env_name${NC}\n";
            if (add_zone($zone_name, $env_name, $region_name)) {
                $successful_components++;
            }
        }
    }
    
    # Process projects
    if ($config->{projects}) {
        foreach my $project (@{$config->{projects}}) {
            $total_components++;
            print "\n${BLUE}Processing project: $project${NC}\n";
            if (add_project($project)) {
                $successful_components++;
            }
        }
    }
    
    # Summary
    print "\n${GREEN}=== Configuration Processing Complete ===${NC}\n";
    print "Total components: $total_components\n";
    print "Successful: $successful_components\n";
    print "Failed: " . ($total_components - $successful_components) . "\n";
    
    if ($successful_components < $total_components) {
        exit 1;
    }
}

sub read_json_config {
    my $config_file = shift;
    
    if (!-f $config_file) {
        die "${RED}Config file not found: $config_file${NC}\n";
    }
    
    # Read file content
    open(my $fh, '<', $config_file) or die "Cannot read $config_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    # Parse JSON
    my $config;
    eval {
        $config = JSON->new->decode($content);
    };
    if ($@) {
        die "${RED}Error parsing JSON config file: $@${NC}\n";
    }
    
    return $config;
}

sub validate_config {
    my $config = shift;
    
    # Check required structure
    if ( !(ref($config) eq 'HASH') ) {
        die "${RED}Config must be a JSON object${NC}\n";
    }
    
    # Validate each section if present
    if ($config->{environments} && ref($config->{environments}) ne 'ARRAY') {
        die "${RED}Environments must be an array${NC}\n";
    }
    
    if ($config->{global_resources} && ref($config->{global_resources}) ne 'ARRAY') {
        die "${RED}Global resources must be an array (deprecated - use environment-level resources instead)${NC}\n";
    }
    
    if ($config->{regions}) {
        if (ref($config->{regions}) ne 'ARRAY') {
            die "${RED}Regions must be an array${NC}\n";
        }
        
        foreach my $region (@{$config->{regions}}) {
            if (!defined $region->{name} || !defined $region->{environment}) {
                die "${RED}Each region must have 'name' and 'environment' fields${NC}\n";
            }
        }
    }
    
    if ($config->{zones}) {
        if (ref($config->{zones}) ne 'ARRAY') {
            die "${RED}Zones must be an array${NC}\n";
        }
        
        foreach my $zone (@{$config->{zones}}) {
            if (!defined $zone->{name} || !defined $zone->{environment} || !defined $zone->{region}) {
                die "${RED}Each zone must have 'name', 'environment', and 'region' fields${NC}\n";
            }
        }
    }
    
    if ($config->{projects} && ref($config->{projects}) ne 'ARRAY') {
        die "${RED}Projects must be an array${NC}\n";
    }
    
    print "${GREEN}✓ Config validation passed${NC}\n" if $verbose;
}

# Run main
main();
