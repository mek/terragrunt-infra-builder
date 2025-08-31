package Resource::Base;
#
# Base class for Resource components
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Basename;
use Resource::Deploy;
use JSON;

# Constructor
sub new {
    my ($class, %args) = @_;
    
    if ($ENV{DEBUG}) {
        print "  Resource::Base->new called for class: $class\n";
        print "    Args received:\n";
        foreach my $key (sort keys %args) {
            print "      $key => " . ($args{$key} || 'undef') . "\n";
        }
    }
    
    my $self = {};
    
    # Required parameters
    $self->{name}           = $args{name} or die "Resource name required";
    $self->{env_name}       = $args{env_name} or die "Environment name required";
    $self->{workspace_root} = $args{workspace_root} or die "Workspace root required";
    $self->{template_dir}   = $args{template_dir} or die "Template directory required";
    
    # Parameters with defaults
    $self->{envs_base} = $args{envs_base} || "envs";
    $self->{dry_run}   = $args{dry_run} || 0;
    $self->{verbose}   = $args{verbose} || 0;
    $self->{force}     = $args{force} || 0;
    
    # Optional parameters
    $self->{region_name}   = $args{region_name} if defined $args{region_name};
    $self->{zone_name}     = $args{zone_name} if defined $args{zone_name};
    $self->{project_name}  = $args{project_name} if defined $args{project_name};
    $self->{resource_type} = $args{resource_type} if defined $args{resource_type};
    
    if ($ENV{DEBUG}) {
        print "    After separate assignment: self->{region_name} = " . (defined($self->{region_name}) ? "'$self->{region_name}'" : 'undef') . "\n";
    }
    
    if ($ENV{DEBUG}) {
        print "    Object created with:\n";
        print "      region_name => " . (defined($self->{region_name}) ? $self->{region_name} : 'undef') . "\n";
    }
    
    bless $self, $class;
    return $self;
}

# Get the resource type (override in subclasses if needed)
sub get_type {
    my $self = shift;
    my $class = ref($self);
    $class =~ s/.*:://;
    return lc($class);
}

# Generate standardized resource name
# Format: <resource>-<env>-<project>-<region>-<zone>
# Only includes components that are defined
sub get_resource_name {
    my $self = shift;
    my $base_name = shift || $self->{name};
    
    my @name_parts = ();
    
    # Start with resource name
    push @name_parts, $base_name;
    
    # Add environment
    push @name_parts, $self->{env_name} if $self->{env_name};
    
    # Add project (if defined)
    push @name_parts, $self->{project_name} if $self->{project_name};
    
    # Add region (if defined)
    push @name_parts, $self->{region_name} if $self->{region_name};
    
    # Add zone (if defined)
    push @name_parts, $self->{zone_name} if $self->{zone_name};
    
    return join('-', @name_parts);
}

# Get the template directory for this resource
sub get_template_dir {
    my $self = shift;
    my $type = $self->get_type();
    die "template_dir not defined" unless $self->{template_dir};
    return "$self->{template_dir}/resources/$type";
}

# Calculate the resource directory path
sub get_resource_path {
    my $self = shift;
    
    die "workspace_root not defined" unless $self->{workspace_root};
    die "envs_base not defined" unless $self->{envs_base};
    die "env_name not defined" unless $self->{env_name};
    die "name not defined" unless $self->{name};
    
    my $path = "$self->{workspace_root}/$self->{envs_base}/$self->{env_name}";
    
    # Add project if specified
    if ($self->{project_name}) {
        $path .= "/$self->{project_name}";
    }
    
    # Add region if specified
    if ($self->{region_name}) {
        $path .= "/$self->{region_name}";
    }
    
    # Add zone if specified
    if ($self->{zone_name}) {
        $path .= "/$self->{zone_name}";
    }
    
    # Add resource name
    $path .= "/$self->{name}";
    
    return $path;
}

# Get hierarchy level (env, region, or zone)
sub get_hierarchy_level {
    my $self = shift;
    
    if ($self->{zone_name}) {
        return "zone";
    } elsif ($self->{region_name}) {
        return "region";
    } else {
        return "env";
    }
}

# Calculate relative path to a dependency
sub get_dependency_path {
    my ($self, $dep_name, $dep_location) = @_;
    
    my $resource_path = $self->get_resource_path();
    my @path_parts = split('/', $resource_path);
    
    # Default location is at the same level as current resource
    $dep_location ||= $self->get_dependency_default_location($dep_name);
    
    # Count how many directories to go up
    my $levels_up = 0;
    if (defined $dep_location) {
        if ($dep_location eq 'env') {
            # Go up to environment level
            $levels_up = $self->{zone_name} ? 3 : ($self->{region_name} ? 2 : 1);
        } elsif ($dep_location eq 'region') {
            # Go up to region level
            $levels_up = $self->{zone_name} ? 2 : 1;
        } elsif ($dep_location eq 'zone') {
            # Same zone level
            $levels_up = 1;
        }
    }
    
    my $relative_path = "../" x $levels_up;
    $relative_path .= $dep_name;
    
    return $relative_path;
}

# Default dependency locations (override in subclasses)
sub get_dependency_default_location {
    my ($self, $dep_name) = @_;
    
    # Enhanced dependency locations for AWS resources
    my %dep_locations = (
        # Environment-level (global) resources
        'iam'                => 'env',
        'route53'            => 'env',
        'acm'                => 'env',
        'kms'                => 'env',
        'secrets-manager'    => 'env',
        'cloudtrail'         => 'env',
        'guardduty'          => 'env',
        
        # Region-level resources
        'vpc'                => 'region',
        'security-group'     => 'region',
        'internet-gateway'   => 'region',
        'nat-gateway'        => 'region',
        'alb'                => 'region',
        'nlb'                => 'region',
        'rds'                => 'region',
        'aurora'             => 'region',
        'dynamodb'           => 'region',
        'elasticache'        => 'region',
        'opensearch'         => 'region',
        's3'                 => 'region',
        'efs'                => 'region',
        'ecr'                => 'region',
        'cloudwatch'         => 'region',
        'sns'                => 'region',
        'sqs'                => 'region',
        'lambda'             => 'region',
        'api-gateway'        => 'region',
        'cloudfront'         => 'region',
        
        # Zone-level resources (typically workload-specific)
        'eks'                => 'zone',
        'ecs'                => 'zone',
        'ec2'                => 'zone',
        'batch'              => 'zone',
    );
    
    return $dep_locations{$dep_name} || 'region';
}

# Get AWS service category for a resource type
sub get_aws_service_category {
    my ($self, $resource_type) = @_;
    $resource_type = $resource_type || $self->get_type();
    
    my %categories = (
        compute     => ['eks', 'ecs', 'ec2', 'lambda', 'batch', 'lightsail', 'fargate'],
        networking  => ['vpc', 'security-group', 'alb', 'nlb', 'internet-gateway', 'nat-gateway', 'route53', 'cloudfront', 'api-gateway'],
        storage     => ['s3', 'efs', 'fsx', 'ebs', 'backup'],
        database    => ['rds', 'aurora', 'dynamodb', 'elasticache', 'documentdb', 'neptune'],
        security    => ['iam', 'kms', 'secrets-manager', 'acm', 'waf', 'shield', 'guardduty'],
        monitoring  => ['cloudwatch', 'cloudtrail', 'sns', 'sqs', 'eventbridge', 'ssm'],
        analytics   => ['opensearch', 'sagemaker', 'emr', 'glue', 'athena', 'kinesis'],
        devops      => ['codebuild', 'codepipeline', 'codecommit', 'codedeploy'],
    );
    
    foreach my $category (keys %categories) {
        if (grep { $_ eq $resource_type } @{$categories{$category}}) {
            return $category;
        }
    }
    
    return 'other';
}

# Get common dependencies for a resource type
sub get_common_dependencies {
    my ($self, $resource_type) = @_;
    $resource_type = $resource_type || $self->get_type();
    
    # Common dependency patterns for AWS resources
    my %dependencies = (
        'eks'            => ['vpc', 'security-group', 'iam'],
        'ecs'            => ['vpc', 'security-group', 'iam', 'alb'],
        'rds'            => ['vpc', 'security-group'],
        'aurora'         => ['vpc', 'security-group'],
        'elasticache'    => ['vpc', 'security-group'],
        'alb'            => ['vpc', 'security-group'],
        'nlb'            => ['vpc'],
        'lambda'         => ['iam', 'security-group'],
        'api-gateway'    => ['iam'],
        'opensearch'     => ['vpc', 'security-group', 'iam'],
        'batch'          => ['vpc', 'security-group', 'iam', 'ecs'],
    );
    
    return $dependencies{$resource_type} || [];
}

# Get template variables for substitution
sub get_template_variables {
    my $self = shift;
    
    my %vars = (
        env_name       => $self->{env_name} || '',
        region_name    => $self->{region_name} || '',
        zone_name      => $self->{zone_name} || '',
        project_name   => $self->{project_name} || '',
        resource_name  => $self->{name} || '',
        full_name      => $self->get_resource_name(),  # New standardized name
        zone_suffix    => $self->{zone_name} ? "-$self->{zone_name}" : '',
    );
    
    # Add dependency paths
    $vars{vpc_path} = $self->get_dependency_path('vpc');
    $vars{sg_path} = $self->get_dependency_path('security-group');
    
    return %vars;
}

# Process template file
sub process_template {
    my ($self, $template_file, $output_file) = @_;
    
    # Read template
    open(my $in_fh, '<', $template_file) or die "Cannot read $template_file: $!";
    my $content = do { local $/; <$in_fh> };
    close $in_fh;
    
    # Get variables
    my %vars = $self->get_template_variables();
    
    # Replace variables
    foreach my $key (keys %vars) {
        my $value = $vars{$key};
        $content =~ s/\{\{$key\}\}/$value/g;
    }
    
    # Clean up sections based on hierarchy
    $content = $self->cleanup_template_content($content);
    
    # Write output
    open(my $out_fh, '>', $output_file) or die "Cannot write $output_file: $!";
    print $out_fh $content;
    close $out_fh;
}

# Clean up template content based on hierarchy
sub cleanup_template_content {
    my ($self, $content) = @_;
    
    # Remove region-specific sections if no region
    if (!$self->{region_name}) {
        $content =~ s/include "region".*?\}\n\n//s;
        $content =~ s/.*region_vars.*\n//g;
        $content =~ s/.*aws_region.*\n//g;
        $content =~ s/\s*Region\s*=.*\n//g;
    }
    
    # Remove zone-specific sections if no zone
    if (!$self->{zone_name}) {
        $content =~ s/.*zone\s*=.*\n//g;
        $content =~ s/\s*Zone\s*=.*\n//g;
        $content =~ s/# Zone:.*\n//g;
    }
    
    return $content;
}

# Copy template directory to resource directory
sub copy_template_dir {
    my $self = shift;
    
    my $template_dir = $self->get_template_dir();
    my $resource_path = $self->get_resource_path();
    
    # Create resource directory
    make_path($resource_path) unless $self->{dry_run};
    
    # Copy all files from template directory
    opendir(my $dh, $template_dir) or die "Cannot open $template_dir: $!";
    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;
        next if $file =~ /\.pm$/;  # Skip Perl modules
        
        my $src = "$template_dir/$file";
        my $dst = "$resource_path/$file";
        
        if (-f $src) {
            if ($file eq 'terragrunt.hcl') {
                # Process template file
                $self->process_template($src, $dst) unless $self->{dry_run};
            } else {
                # Copy as-is
                copy($src, $dst) unless $self->{dry_run};
            }
        }
    }
    closedir($dh);
}

# Main method to create the resource
sub create {
    my $self = shift;
    
    my $resource_path = $self->get_resource_path();
    my $hierarchy = $self->get_hierarchy_level();
    my $type = $self->get_type();
    
    print "Adding resource '$self->{name}' (type: $type) at $hierarchy level\n" if $self->{verbose};
    
    # Check if resource already exists
    if (-d $resource_path && !$self->{force} && !$self->{dry_run}) {
        die "Resource $self->{name} already exists. Use -f to force overwrite.\n";
    }
    
    if ($self->{dry_run}) {
        print "  [DRY RUN] Would create: $resource_path\n";
        print "  [DRY RUN] Resource type: $type\n";
        print "  [DRY RUN] Template: " . $self->get_template_dir() . "\n";
        return 1;
    }
    
    # Copy and process template
    $self->copy_template_dir();
    
    # Generate deploy.pl file for terragrunt-deploy.pl integration
    $self->generate_deploy_file();
    
    # Run any post-creation hooks
    $self->post_create();
    
    return 1;
}

# Generate deploy.pl file for terragrunt-deploy.pl integration
sub generate_deploy_file {
    my $self = shift;
    
    print "  Generating deploy.pl file for terragrunt-deploy.pl integration\n" if $self->{verbose};
    
    my $resource_path = $self->get_resource_path();
    my $full_name = $self->get_resource_name();
    my $resource_type = $self->get_type();
    
    eval {
        Resource::Deploy->generate_deploy_file(
            resource_path => $resource_path,
            resource_name => $self->{name},
            resource_type => $resource_type,
            env_name => $self->{env_name},
            region_name => $self->{region_name},
            zone_name => $self->{zone_name},
            project_name => $self->{project_name},
            full_name => $full_name,
        );
        
        print "  ✓ Deploy.pl file generated successfully\n" if $self->{verbose};
    };
    
    if ($@) {
        warn "  Warning: Failed to generate deploy.pl file: $@\n";
    }
}

# Post-creation hook (override in subclasses if needed)
sub post_create {
    my $self = shift;
    # Default: do nothing
}

# Validation hook (override in subclasses if needed)
sub validate {
    my $self = shift;
    return 1;  # Default: always valid
}


1;