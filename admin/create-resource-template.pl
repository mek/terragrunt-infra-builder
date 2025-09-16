#!/usr/bin/env perl
#
# AWS Resource Template Generator
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use lib 'lib';
use File::Path qw(make_path);
use File::Basename;
use Getopt::Long;
use POSIX qw(strftime);
use JSON;
use Cwd 'abs_path';
use lib '../lib';
use Resource::Factory;
use Util::Color;
use Util::Config;

# Global variables
my $workspace_root;
my $template_dir;
my $config_file = undef;
my $config;

# Command line options
my $resource_type;
my $verbose = 0;
my $force = 0;

GetOptions(
    'type|t=s'       => \$resource_type,
    'template-dir=s' => \$template_dir,  # Can still override
    'config-file=s'  => \my $config_file_override,
    'verbose|v'      => \$verbose,
    'force|f'        => \$force,
    'help|h'         => sub { print_help(); exit 0; }
) or die "Error in command line arguments\n";

# Main execution
sub main {
    # Initialize colors
    Util::Color::init_colors();

    print "${BOLD}${GREEN}AWS Resource Template Generator${NC}\n";
    print "=" x 60 . "\n\n";

    # Find workspace root
    find_workspace_root();

    # Load configuration
    if ($config_file_override) {
        $config_file = $config_file_override;
    }
    $config = Util::Config->new( 
      file => $config_file, 
      verbose => $verbose
    );

    Util::Config->set_instance($config);

    # Set template directory from config (unless overridden)
    if (!$template_dir) {
        $template_dir = "$workspace_root/" . get_config_value("templates.base_path");
    }
    print "${CYAN}Using template directory: $template_dir${NC}\n" if $verbose;
    
    if (!$resource_type) {
        print "${RED}Error: Resource type required${NC}\n\n";
        print_help();
        exit 1;
    }
    
    # Validate resource type
    my %supported_types = Resource::Factory::get_supported_resource_types();
    if (!exists $supported_types{$resource_type}) {
        print "${RED}Error: Unknown resource type '$resource_type'${NC}\n";
        
        my @suggestions = Resource::Factory::suggest_resource_types($resource_type);
        if (@suggestions) {
            print "${YELLOW}Did you mean one of these?${NC}\n";
            foreach my $suggestion (@suggestions) {
                print "  - $suggestion\n";
            }
        }
        
        print "\n${CYAN}Use './admin/create-resource-template.pl --help' to see all supported types${NC}\n";
        exit 1;
    }
    
    # Get canonical type name
    my $canonical_type = $supported_types{$resource_type};
    
    print "${CYAN}Creating template for: $canonical_type${NC}\n";
    if ($resource_type ne $canonical_type) {
        print "${YELLOW}  (resolved from alias: $resource_type)${NC}\n";
    }
    
    # Create template structure
    create_template_structure($canonical_type);
    
    print "\n${GREEN}✓ Template created successfully!${NC}\n";
    print_next_steps($canonical_type);
}

sub print_help {
    print <<'HELP';
AWS Resource Template Generator

Usage: ./admin/create-resource-template.pl -t <resource_type> [OPTIONS]

Options:
    -t, --type <type>       AWS resource type to create template for
    --template-dir <dir>    Override template directory (default: from config)
    --config-file <file>    Configuration file (default: config/manage-config.yaml)
    -v, --verbose           Verbose output
    -f, --force             Force overwrite existing template
    -h, --help              Show this help message

Supported Resource Types:
HELP

    # Show supported types by category
    my %categories = Resource::Factory::get_resource_types_by_category();
    
    foreach my $category (sort keys %categories) {
        print "\n" . ucfirst($category) . ":\n";
        my $resources = $categories{$category};
        foreach my $resource (sort @$resources) {
            print "  - $resource\n";
        }
    }
    
    print <<'HELP';

Examples:
    # Create EKS template
    ./admin/create-resource-template.pl -t eks
    
    # Create VPC template with verbose output
    ./admin/create-resource-template.pl -t vpc -v
    
    # Create security group template using alias
    ./admin/create-resource-template.pl -t sg

HELP
}

sub create_template_structure {
    my ($resource_type) = @_;
    
    my $template_path = "$template_dir/resources/$resource_type";
    
    # Check if template already exists
    if (-d $template_path && !$force) {
        print "${YELLOW}Template already exists at: $template_path${NC}\n";
        print "${YELLOW}Use -f to force overwrite${NC}\n";
        return;
    }
    
    print "  Creating directory: $template_path\n" if $verbose;
    make_path($template_path);
    
    # Create terragrunt.hcl template
    create_terragrunt_template($template_path, $resource_type);
    
    # Generate inputs.json from module analysis
    generate_inputs_json_template($template_path, $resource_type);
    
    # Create Perl resource module
    create_resource_module($template_path, $resource_type);
    
    # Create README
    create_template_readme($template_path, $resource_type);
}

sub create_terragrunt_template {
    my ($template_path, $resource_type) = @_;
    
    my $file_path = "$template_path/terragrunt.hcl";
    print "  Creating: $file_path\n" if $verbose;
    
    # Get resource info for smart defaults
    my %type_map = Resource::Factory::get_supported_resource_types();
    my %categories = Resource::Factory::get_resource_types_by_category();
    
    my $category = get_resource_category($resource_type, %categories);
    my $terraform_module = get_terraform_module_suggestion($resource_type);
    
    my $content = generate_terragrunt_template_content($resource_type, $category, $terraform_module);
    
    open(my $fh, '>', $file_path) or die "Cannot write $file_path: $!";
    print $fh $content;
    close $fh;
}

sub create_resource_module {
    my ($template_path, $resource_type) = @_;
    
    my $file_path = "$template_path/Resource.pm";
    print "  Creating: $file_path\n" if $verbose;
    
    my $module_name = get_module_name($resource_type);
    my $content = generate_resource_module_content($resource_type, $module_name);
    
    open(my $fh, '>', $file_path) or die "Cannot write $file_path: $!";
    print $fh $content;
    close $fh;
}

sub create_template_readme {
    my ($template_path, $resource_type) = @_;
    
    my $file_path = "$template_path/README.md";
    print "  Creating: $file_path\n" if $verbose;
    
    my $content = generate_readme_content($resource_type);
    
    open(my $fh, '>', $file_path) or die "Cannot write $file_path: $!";
    print $fh $content;
    close $fh;
}

sub get_resource_category {
    my ($resource_type, %categories) = @_;
    
    foreach my $category (keys %categories) {
        if (grep { $_ eq $resource_type } @{$categories{$category}}) {
            return $category;
        }
    }
    return 'other';
}

sub get_terraform_module_suggestion {
    my ($resource_type) = @_;
    
    # Common terraform-aws-modules mapping
    my %module_map = (
        'eks'         => 'eks',
        'vpc'         => 'vpc',
        'rds'         => 'rds',
        'aurora'      => 'rds-aurora',
        'alb'         => 'alb',
        'nlb'         => 'alb',  # Uses same module
        'ec2'         => 'ec2-instance',
        'lambda'      => 'lambda',
        'ecs'         => 'ecs',
        's3'          => 's3-bucket',
        'iam'         => 'iam',
        'kms'         => 'kms',
        'dynamodb'    => 'dynamodb-table',
        # External resources use local modules
        'external-vpc'        => '../../../../modules/external-vpc-data',
        'external-s3-backend' => '../../../../modules/external-s3-backend-data',
    );
    
    return $module_map{$resource_type} || $resource_type;
}

sub get_module_name {
    my ($resource_type) = @_;
    
    my $module_name = "Resource::" . ucfirst($resource_type);
    $module_name =~ s/-([a-z])/\U$1/g;  # Convert kebab-case to CamelCase
    
    # Special cases for common abbreviations
    $module_name =~ s/^Resource::Eks$/Resource::EKS/;
    $module_name =~ s/^Resource::Rds$/Resource::RDS/;
    $module_name =~ s/^Resource::Iam$/Resource::IAM/;
    $module_name =~ s/^Resource::Vpc$/Resource::VPC/;
    $module_name =~ s/^Resource::Alb$/Resource::ALB/;
    $module_name =~ s/^Resource::Nlb$/Resource::NLB/;
    $module_name =~ s/^Resource::Ecs$/Resource::ECS/;
    $module_name =~ s/^Resource::Ecr$/Resource::ECR/;
    $module_name =~ s/^Resource::S3$/Resource::S3/;
    $module_name =~ s/^Resource::Kms$/Resource::KMS/;
    
    return $module_name;
}

sub generate_terragrunt_template_content {
    my ($resource_type, $category, $terraform_module) = @_;
    
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    
    my $content = <<EOF;
# Terragrunt configuration for {{resource_name}}
# Resource type: $resource_type
# Category: $category
# Environment: {{env_name}}
# Region: {{region_name}}
# Zone: {{zone_name}}
# Generated: $timestamp

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path = find_in_parent_folders("region.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  
  environment = local.env_vars.locals.environment
  aws_region = local.region_vars.locals.aws_region
  zone = "{{zone_name}}"
  
  # Load inputs from inputs.json if it exists, otherwise use empty map
  inputs_file_exists = fileexists("\${get_terragrunt_dir()}/inputs.json")
  external_inputs = local.inputs_file_exists ? jsondecode(file("\${get_terragrunt_dir()}/inputs.json")) : {}
}

terraform {
EOF

    # Handle external resources differently
    if ($resource_type =~ /^external-/) {
        $content .= <<EOF;
  source = "$terraform_module"
EOF
    } else {
        $content .= <<EOF;
  # Choose the appropriate source for your $resource_type resource:
  source = "tfr:///terraform-aws-modules/$terraform_module/aws"
  # source = "git::https://github.com/terraform-aws-modules/terraform-aws-$terraform_module.git"
  # source = "../../modules/$resource_type"
EOF
    }
    
    $content .= <<EOF;
}

inputs = merge(
  # Default inputs - these can be overridden by inputs.json
  {
EOF

    # Handle external-vpc specifically
    if ($resource_type eq 'external-vpc') {
        $content .= <<EOF;
  # Common tags applied to resources
  tags = {
    Environment = local.environment
    Region      = local.aws_region
    Zone        = local.zone
    ManagedBy   = "Terragrunt"
    Resource    = "{{resource_name}}"
    Type        = "$resource_type"
    Category    = "$category"
  }
  
  # External VPC Configuration - replace with actual values
  vpc_id     = "REPLACE_WITH_ACTUAL_VPC_ID"
  vpc_cidr   = "REPLACE_WITH_VPC_CIDR"
  
  # Subnet IDs - update with actual subnet IDs
  private_subnet_ids  = ["REPLACE_WITH_PRIVATE_SUBNET_1", "REPLACE_WITH_PRIVATE_SUBNET_2"]
  public_subnet_ids   = ["REPLACE_WITH_PUBLIC_SUBNET_1", "REPLACE_WITH_PUBLIC_SUBNET_2"]
  database_subnet_ids = []  # Optional - add if you have database subnets
  
  # Subnet CIDR blocks
  private_subnet_cidrs = ["REPLACE_WITH_PRIVATE_CIDR_1", "REPLACE_WITH_PRIVATE_CIDR_2"]
  public_subnet_cidrs  = ["REPLACE_WITH_PUBLIC_CIDR_1", "REPLACE_WITH_PUBLIC_CIDR_2"]
  
  # Availability zones
  availability_zones = ["\${local.aws_region}a", "\${local.aws_region}b"]
  
  # Optional gateway IDs
  internet_gateway_id = ""  # Optional - add if needed
  nat_gateway_ids     = []  # Optional - add if you have NAT gateways
  route_table_ids     = []  # Optional - add if you need specific route tables
EOF
    } elsif ($resource_type eq 'external-s3-backend') {
        $content .= <<EOF;
  # Common tags applied to resources
  tags = {
    Environment = local.environment
    Region      = local.aws_region
    Zone        = local.zone
    ManagedBy   = "Terragrunt"
    Resource    = "{{resource_name}}"
    Type        = "$resource_type"
    Category    = "$category"
  }
  
  # External S3 Backend Configuration - replace with actual values
  bucket_name = "REPLACE_WITH_ACTUAL_BUCKET_NAME"
  dynamodb_table = "REPLACE_WITH_ACTUAL_DYNAMODB_TABLE"
  kms_key_id = ""  # Optional - add if using KMS encryption
EOF
    } else {
        $content .= <<EOF;
  # Standard naming convention
  name = "{{full_name}}"
  
  # Common tags applied to all resources
  tags = {
    Environment = local.environment
    Region      = local.aws_region
    Zone        = local.zone
    ManagedBy   = "Terragrunt"
    Resource    = "{{resource_name}}"
    Type        = "$resource_type"
    Category    = "$category"
  }
  
  # TODO: Add $resource_type-specific configuration here
  # Refer to inputs.json for available variables
  # Example configurations:
  
  # Common AWS resource settings
  # vpc_id = dependency.vpc.outputs.vpc_id
  # subnet_ids = dependency.vpc.outputs.private_subnets
  # security_group_ids = [dependency.security_group.outputs.security_group_id]
EOF
    }
    
    $content .= <<EOF;
  },
  
  # External inputs from inputs.json (if it exists)
  # These take precedence over the defaults above
  local.external_inputs
)

# TODO: Add dependencies as needed
# dependency "vpc" {
#   config_path = "{{vpc_path}}"
# }
#
# dependency "security_group" {
#   config_path = "{{sg_path}}"
# }
EOF

    return $content;
}

sub generate_resource_module_content {
    my ($resource_type, $module_name) = @_;
    
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    
    return <<EOF;
package $module_name;

use strict;
use warnings;
use base 'Resource::Base';

# Generated: $timestamp
# Resource type: $resource_type

# Constructor
sub new {
    my (\$class, \%args) = \@_;
    my \$self = \$class->SUPER::new(\%args);
    
    return \$self;
}

# Override resource type
sub get_type {
    return '$resource_type';
}

# Override validation if needed
sub validate {
    my \$self = shift;
    
    # Add $resource_type-specific validation here
    # Examples:
    # - Check required parameters
    # - Validate resource naming conventions
    # - Verify dependencies exist
    
    return \$self->SUPER::validate();
}

# Override post-creation hook if needed
sub post_create {
    my \$self = shift;
    
    print "  $resource_type resource created successfully\\n" if \$self->{verbose};
    
    # Add $resource_type-specific post-creation tasks here
    # Examples:
    # - Generate additional configuration files
    # - Set up dependencies
    # - Create helper scripts
    
    return \$self->SUPER::post_create();
}

# Add $resource_type-specific methods here
# Examples:
# sub generate_kubeconfig { } # for EKS
# sub get_connection_string { } # for RDS
# sub get_load_balancer_dns { } # for ALB/NLB

1;
EOF
}

sub generate_readme_content {
    my ($resource_type) = @_;
    
    my $timestamp = strftime("%Y-%m-%d", localtime);
    my $category = get_resource_category($resource_type, Resource::Factory::get_resource_types_by_category());
    my $module_suggestion = get_terraform_module_suggestion($resource_type);
    
    # Add common dependencies based on resource type
    my %dependencies = (
        'eks'            => ['vpc', 'security-group', 'iam'],
        'ecs'            => ['vpc', 'security-group', 'iam', 'alb'],
        'rds'            => ['vpc', 'security-group'],
        'rds-mysql'      => ['vpc', 'security-group'],
        'rds-postgres'   => ['vpc', 'security-group'],
        'aurora'         => ['vpc', 'security-group'],
        'aurora-mysql'   => ['vpc', 'security-group'],
        'aurora-postgres' => ['vpc', 'security-group'],
        'elasticache'    => ['vpc', 'security-group'],
        'alb'            => ['vpc', 'security-group'],
        'nlb'            => ['vpc'],
        'lambda'         => ['iam', 'security-group'],
        'api-gateway'    => ['iam'],
        'opensearch'     => ['vpc', 'security-group', 'iam'],
        'batch'          => ['vpc', 'security-group', 'iam', 'ecs'],
    );
    
    my $content = <<EOF;
# $resource_type Template

Generated: $timestamp
Category: $category
Terraform Module: terraform-aws-modules/$module_suggestion

## Description

This template creates AWS $resource_type resources using Terragrunt.

## Usage

\`\`\`bash
# Create $resource_type resource
./manage.pl add resource "$resource_type" -e <env> -r <region>

# For zone-level resources
./manage.pl add resource "$resource_type" -e <env> -r <region> -z <zone>
\`\`\`

## Configuration

The template includes:

- Standard terragrunt.hcl configuration
- Resource-specific Perl module ($resource_type/Resource.pm)
- Common AWS tags and naming conventions
- Dependency management setup

## Customization

1. **terragrunt.hcl**: Modify the terraform source and inputs
2. **Resource.pm**: Add validation and post-creation logic
3. **Dependencies**: Uncomment and configure dependency blocks as needed

## Common Dependencies

Based on the resource type, you may need:

EOF
    
    if (exists $dependencies{$resource_type}) {
        foreach my $dep (@{$dependencies{$resource_type}}) {
            $content .= "- $dep\n";
        }
    } else {
        $content .= "- Check AWS documentation for specific dependencies\n";
    }
    
    $content .= <<EOF;

## Next Steps

1. Run the terraform-module-analyzer to generate inputs.json
2. Customize the terragrunt.hcl with specific configuration
3. Test with --dry-run flag first
4. Deploy using terragrunt-deploy.pl

## References

- [Terraform AWS Modules](https://github.com/terraform-aws-modules)
- [AWS $resource_type Documentation](https://docs.aws.amazon.com/)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
EOF
    
    return $content;
}

# Generate inputs.json template from Terraform module analysis
sub generate_inputs_json_template {
    my ($template_path, $resource_type) = @_;
    
    print "  Analyzing Terraform module to generate inputs.json template...\n" if $verbose;
    
    # Extract module source from the just-created terragrunt.hcl
    my $module_source = extract_module_source_from_template("$template_path/terragrunt.hcl");
    
    if (!$module_source) {
        print "    ${YELLOW}Warning: Could not extract module source, creating basic inputs.json${NC}\n";
        create_basic_inputs_json($template_path, $resource_type);
        return;
    }
    
    print "    Module source: $module_source\n" if $verbose;
    
    # Clone and analyze the module
    my $variables = clone_and_analyze_terraform_module($module_source);
    
    if (!$variables || !@$variables) {
        print "    ${YELLOW}Warning: Could not analyze module, creating basic inputs.json${NC}\n";
        create_basic_inputs_json($template_path, $resource_type);
        return;
    }
    
    # Create inputs.json with actual module variables
    create_inputs_json_from_variables($template_path, $resource_type, $variables, $module_source);
    
    print "    ✓ inputs.json generated with " . scalar(@$variables) . " variables from module analysis\n";
}

# Extract module source from terragrunt.hcl template
sub extract_module_source_from_template {
    my ($terragrunt_file) = @_;
    
    return unless -f $terragrunt_file;
    
    open(my $fh, '<', $terragrunt_file) or return;
    my $content = do { local $/; <$fh> };
    close $fh;
    
    # Look for active (uncommented) source line
    if ($content =~ /^\s*source\s*=\s*"([^"]+)"/m) {
        return $1;
    }
    
    return;
}

# Clone repository and analyze variables.tf
sub clone_and_analyze_terraform_module {
    my ($module_source) = @_;
    
    # Parse module source
    my $module_info = parse_terraform_module_source($module_source);
    return unless $module_info;
    
    print "    Cloning: $module_info->{repo}\n" if $verbose;
    
    # Create temporary directory
    my $temp_dir = "/tmp/terraform_template_analysis_" . time() . "_$$";
    my $repo_dir = "$temp_dir/repo";
    
    # Clone repository
    my $clone_cmd = "git clone --depth 1";
    $clone_cmd .= " --branch '$module_info->{ref}'" if $module_info->{ref};
    $clone_cmd .= " '$module_info->{repo}' '$repo_dir' 2>/dev/null";
    
    my $result = system($clone_cmd);
    if ($result != 0) {
        system("rm -rf '$temp_dir'") if -d $temp_dir;
        return;
    }
    
    # Find variables.tf
    my $variables_file = find_terraform_variables_file($repo_dir, $module_info->{module_path});
    my $variables = [];
    
    if ($variables_file) {
        print "    Parsing: $variables_file\n" if $verbose;
        $variables = parse_terraform_variables_file($variables_file);
    }
    
    # Clean up
    system("rm -rf '$temp_dir'") if -d $temp_dir;
    
    return $variables;
}

# Parse Terraform module source URL
sub parse_terraform_module_source {
    my ($source) = @_;
    
    # Handle Terraform Registry format: tfr:///terraform-aws-modules/vpc/aws?version=5.5.1
    if ($source =~ /^tfr:\/\/\/(.+?)\/(.+?)\/(.+?)(?:\?(.+))?$/) {
        my ($namespace, $name, $provider, $query) = ($1, $2, $3, $4);
        my $version;
        
        if ($query && $query =~ /version=([^&]+)/) {
            $version = $1;
        }
        
        return {
            type => 'terraform_registry',
            repo => "https://github.com/$namespace/terraform-$provider-$name.git",
            module_path => '',
            ref => $version
        };
    }
    # Handle git::https format
    elsif ($source =~ /^git::(.+)$/) {
        my $url_part = $1;
        my ($url, $ref, $module_path);
        
        if ($url_part =~ /(.+)\?(.+)$/) {
            $url = $1;
            my $query = $2;
            if ($query =~ /ref=([^&]+)/) {
                $ref = $1;
            }
        } else {
            $url = $url_part;
        }
        
        # Extract module path if present
        if ($url =~ /(.+)\/\/(.+)$/) {
            ($url, $module_path) = ($1, $2);
        }
        
        return {
            type => 'git_https',
            repo => $url,
            module_path => $module_path || '',
            ref => $ref
        };
    }
    
    return;
}

# Find variables.tf in cloned repository
sub find_terraform_variables_file {
    my ($repo_dir, $module_path) = @_;
    
    my $search_dir = $repo_dir;
    if ($module_path) {
        $search_dir = "$repo_dir/$module_path";
    }
    
    my $variables_file = "$search_dir/variables.tf";
    return $variables_file if -f $variables_file;
    
    # Try root if module_path didn't work
    if ($module_path) {
        $variables_file = "$repo_dir/variables.tf";
        return $variables_file if -f $variables_file;
    }
    
    return;
}

# Parse variables.tf file
sub parse_terraform_variables_file {
    my ($variables_file) = @_;
    
    open(my $fh, '<', $variables_file) or return [];
    my $content = do { local $/; <$fh> };
    close $fh;
    
    my @variables;
    
    # Parse variable blocks
    while ($content =~ /variable\s+"([^"]+)"\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}/gs) {
        my ($var_name, $var_body) = ($1, $2);
        
        my $var_info = {
            name => $var_name,
            description => '',
            type => 'string',
            default => undef,
            required => 1
        };
        
        # Extract description
        if ($var_body =~ /description\s*=\s*"([^"]*)"/s) {
            $var_info->{description} = $1;
        }
        
        # Extract type
        if ($var_body =~ /type\s*=\s*([^\s\n]+)/s) {
            $var_info->{type} = $1;
        }
        
        # Check for default value
        if ($var_body =~ /default\s*=/) {
            $var_info->{required} = 0;
            # Extract default value (simplified - could be enhanced)
            if ($var_body =~ /default\s*=\s*([^}]+?)(?=\n\s*[a-z_]|\n\s*}|\s*})/s) {
                my $default_val = $1;
                $default_val =~ s/^\s+|\s+$//g;
                $var_info->{default} = $default_val;
            }
        }
        
        push @variables, $var_info;
    }
    
    return \@variables;
}

# Create inputs.json from analyzed variables
sub create_inputs_json_from_variables {
    my ($template_path, $resource_type, $variables, $module_source) = @_;
    
    my $inputs_file = "$template_path/inputs.json";
    print "  Creating: $inputs_file\n" if $verbose;
    
    my $inputs = {
        '_metadata' => {
            generated_by => 'create-resource-template.pl',
            generated_at => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
            resource_type => $resource_type,
            module_source => $module_source,
            terraform_module_analyzed => JSON::true
        },
        'template_variables' => {
            resource_name => '{{resource_name}}',
            full_name => '{{full_name}}',
            env_name => '{{env_name}}',
            region_name => '{{region_name}}',
            zone_name => '{{zone_name}}',
            project_name => '{{project_name}}'
        },
        'module_variables' => {}
    };
    
    # Add each variable from the Terraform module
    foreach my $var (@$variables) {
        my $var_entry = {
            description => $var->{description} || "Variable from Terraform module",
            type => $var->{type} || 'string',
            required => $var->{required} ? JSON::true : JSON::false
        };
        
        if (defined $var->{default}) {
            $var_entry->{default} = $var->{default};
        }
        
        # Add usage hints for common variables
        if ($var->{name} =~ /^(name|identifier)$/) {
            $var_entry->{template_suggestion} = "Use {{full_name}} for consistent naming";
        } elsif ($var->{name} eq 'tags') {
            $var_entry->{template_suggestion} = "Standard tags are added in terragrunt.hcl";
        } elsif ($var->{name} =~ /^(vpc_id|subnet_ids?|security_group_ids?)$/) {
            $var_entry->{template_suggestion} = "Reference from dependency block in terragrunt.hcl";
        }
        
        $inputs->{module_variables}->{$var->{name}} = $var_entry;
    }
    
    open(my $fh, '>', $inputs_file) or die "Cannot write $inputs_file: $!";
    print $fh JSON->new->pretty->canonical->encode($inputs);
    close $fh;
}

# Create basic inputs.json if module analysis fails
sub create_basic_inputs_json {
    my ($template_path, $resource_type) = @_;
    
    my $inputs_file = "$template_path/inputs.json";
    print "  Creating basic: $inputs_file\n" if $verbose;
    
    my $inputs = {
        '_metadata' => {
            generated_by => 'create-resource-template.pl',
            generated_at => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
            resource_type => $resource_type,
            module_source => 'unknown',
            terraform_module_analyzed => JSON::false,
            note => 'Basic template - run terraform-module-analyzer.pl for detailed analysis'
        },
        'template_variables' => {
            resource_name => '{{resource_name}}',
            full_name => '{{full_name}}',
            env_name => '{{env_name}}',
            region_name => '{{region_name}}',
            zone_name => '{{zone_name}}',
            project_name => '{{project_name}}'
        },
        'module_variables' => {
            name => {
                description => "Resource name",
                type => "string",
                required => JSON::true,
                template_suggestion => "Use {{full_name}} for consistent naming"
            },
            tags => {
                description => "Tags to apply to resources",
                type => "map(string)",
                required => JSON::false,
                template_suggestion => "Standard tags are added in terragrunt.hcl"
            }
        }
    };
    
    open(my $fh, '>', $inputs_file) or die "Cannot write $inputs_file: $!";
    print $fh JSON->new->pretty->canonical->encode($inputs);
    close $fh;
}

sub print_next_steps {
    my ($resource_type) = @_;
    
    print "\n${BOLD}Next Steps:${NC}\n";
    print "1. Review and customize the generated template files\n";
    print "2. ${GREEN}inputs.json has been generated from module analysis${NC}\n";
    print "3. Test resource creation:\n";
    print "   ${CYAN}./manage.pl add resource \"$resource_type\" -e dev -r us-west-2 --dry-run${NC}\n";
    print "4. Deploy when ready:\n";
    print "   ${CYAN}./manage.pl add resource \"$resource_type\" -e dev -r us-west-2${NC}\n";
    print "\n${YELLOW}Template location: $template_dir/resources/$resource_type/${NC}\n";
}

# Helper functions from manage.pl for configuration handling

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

    print "${GREEN}Workspace root: $workspace_root${NC}\n" if $verbose;
}

# Run main
main();
