package Resource::Deploy;

use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);

# Module for generating deploy.pl files that work with terragrunt-deploy.pl

sub generate_deploy_file {
    my $class = shift;
    my %args = @_;
    
    my $resource_path = $args{resource_path} || die "resource_path required";
    my $resource_name = $args{resource_name} || basename($resource_path);
    my $resource_type = $args{resource_type} || 'generic';
    my $env_name = $args{env_name};
    my $region_name = $args{region_name};
    my $zone_name = $args{zone_name};
    my $project_name = $args{project_name};
    my $full_name = $args{full_name} || $resource_name;
    
    # Determine deployment metadata based on resource type and context
    my $deploy_config = $class->get_deploy_config(
        resource_type => $resource_type,
        resource_name => $resource_name,
        resource_path => $resource_path,
        env_name => $env_name,
        region_name => $region_name,
        zone_name => $zone_name,
        project_name => $project_name,
        full_name => $full_name,
    );
    
    # Generate the deploy.pl file content
    my $deploy_content = $class->generate_deploy_content($deploy_config);
    
    # Write the deploy.pl file
    my $deploy_file = "$resource_path/deploy.pl";
    open(my $fh, '>', $deploy_file) or die "Cannot create $deploy_file: $!";
    print $fh $deploy_content;
    close $fh;
    
    return $deploy_file;
}

sub get_deploy_config {
    my $class = shift;
    my %args = @_;
    
    my $resource_type = $args{resource_type};
    my $resource_name = $args{resource_name};
    my $resource_path = $args{resource_path};
    my $env_name = $args{env_name};
    my $region_name = $args{region_name};
    my $zone_name = $args{zone_name};
    my $project_name = $args{project_name};
    my $full_name = $args{full_name};
    
    # Base configuration
    my $config = {
        name => $full_name,
        description => "Terraform module for $resource_type: $resource_name",
        priority => 50,
        timeout => 600,  # 10 minutes default
        retry => 1,
        parallel_safe => 1,
        critical => 0,
        tags => {},
        dependencies => [],
        owner => 'infrastructure-team',
        team => 'devops',
        docs => "Auto-generated deployment configuration for $resource_type resource.",
    };
    
    # Resource type specific configurations
    my %type_configs = (
        'vpc' => {
            priority => 90,  # High priority - foundational
            timeout => 900,  # 15 minutes for VPC
            critical => 1,   # VPC failures should stop deployment
            parallel_safe => 0,  # VPC should deploy alone
            tags => { type => 'networking', layer => 'foundation' },
            docs => "VPC provides the foundational networking layer for all resources.",
        },
        'iam' => {
            priority => 95,  # Highest priority - security foundation
            timeout => 300,  # 5 minutes for IAM
            critical => 1,   # IAM failures should stop deployment
            tags => { type => 'security', layer => 'foundation' },
            docs => "IAM roles and policies provide security and access control.",
        },
        'security-group' => {
            priority => 85,  # High priority - security
            timeout => 300,  # 5 minutes
            dependencies => ['../vpc'],  # Depends on VPC
            tags => { type => 'security', layer => 'networking' },
            docs => "Security groups control network access to resources.",
        },
        'eks' => {
            priority => 70,  # Medium-high priority
            timeout => 1800, # 30 minutes for EKS cluster
            critical => 1,   # EKS cluster failures should stop deployment
            dependencies => ['../vpc', '../security-group'],
            tags => { type => 'compute', layer => 'platform' },
            docs => "EKS cluster provides Kubernetes orchestration platform.",
        },
        'eks-nodes' => {
            priority => 60,  # Medium priority
            timeout => 900,  # 15 minutes for node groups
            dependencies => ['../eks'],
            tags => { type => 'compute', layer => 'platform' },
            docs => "EKS node groups provide compute capacity for Kubernetes workloads.",
        },
        'rds' => {
            priority => 65,  # Medium-high priority
            timeout => 1200, # 20 minutes for RDS
            dependencies => ['../vpc', '../security-group'],
            tags => { type => 'database', layer => 'data' },
            docs => "RDS provides managed database services.",
        },
        's3' => {
            priority => 80,  # High priority - storage foundation
            timeout => 300,  # 5 minutes
            parallel_safe => 1,
            tags => { type => 'storage', layer => 'foundation' },
            docs => "S3 provides scalable object storage.",
        },
        'alb' => {
            priority => 40,  # Lower priority - application layer
            timeout => 600,  # 10 minutes
            dependencies => ['../vpc', '../security-group'],
            tags => { type => 'networking', layer => 'application' },
            docs => "Application Load Balancer provides HTTP/HTTPS load balancing.",
        },
    );
    
    # Apply resource type specific config
    if (exists $type_configs{$resource_type}) {
        my $type_config = $type_configs{$resource_type};
        foreach my $key (keys %$type_config) {
            if ($key eq 'tags') {
                # Merge tags
                %{$config->{tags}} = (%{$config->{tags}}, %{$type_config->{tags}});
            } else {
                $config->{$key} = $type_config->{$key};
            }
        }
    }
    
    # Add environment-specific tags
    if ($env_name) {
        $config->{tags}{environment} = $env_name;
        
        # Production environments are more critical
        if ($env_name =~ /^(prod|production)$/i) {
            $config->{critical} = 1;
            $config->{timeout} += 300;  # Add 5 minutes for prod
        }
    }
    
    # Add location tags
    $config->{tags}{region} = $region_name if $region_name;
    $config->{tags}{zone} = $zone_name if $zone_name;
    $config->{tags}{project} = $project_name if $project_name;
    
    # Dependencies are relative paths from the current resource directory
    # For region-level resources depending on other region-level resources:
    # eks-cluster depending on vpc should be "../vpc"
    # For zone-level resources depending on region-level resources:
    # eks-nodes depending on eks-cluster should be "../../eks-cluster"
    
    # The dependencies in the type configs are already correctly set as relative paths
    # No additional adjustment needed here since terragrunt-deploy.pl will resolve them
    
    return $config;
}

sub generate_deploy_content {
    my $class = shift;
    my $config = shift;
    
    # Convert Perl data structures to strings for embedding
    my $tags_str = _hash_to_string($config->{tags});
    my $deps_str = _array_to_string($config->{dependencies});
    
    # Generate pre_deploy hook based on resource type
    my $pre_deploy_hook = $class->generate_pre_deploy_hook($config);
    my $post_deploy_hook = $class->generate_post_deploy_hook($config);
    my $validate_hook = $class->generate_validate_hook($config);
    my $skip_hook = $class->generate_skip_hook($config);
    
    my $content = <<EOF;
#!/usr/bin/env perl
# Auto-generated deploy.pl for terragrunt-deploy.pl
# Resource: $config->{name}
# Generated: @{[scalar localtime]}

use strict;
use warnings;
use lib '../../lib';  # Adjust path to reach lib directory
use Deploy::Module;

# Create Deploy::Module object with resource-specific configuration
Deploy::Module->new(
    name => '$config->{name}',
    description => '$config->{description}',
    priority => $config->{priority},
    timeout => $config->{timeout},
    retry => $config->{retry},
    parallel_safe => $config->{parallel_safe},
    critical => $config->{critical},
    tags => $tags_str,
    dependencies => $deps_str,
    owner => '$config->{owner}',
    team => '$config->{team}',
    docs => '$config->{docs}',
    
    # Deployment hooks
    pre_deploy => $pre_deploy_hook,
    post_deploy => $post_deploy_hook,
    validate => $validate_hook,
    skip_if => $skip_hook,
);
EOF

    return $content;
}

sub generate_pre_deploy_hook {
    my $class = shift;
    my $config = shift;
    
    my $name = $config->{name};
    
    return <<EOF;
sub {
        my (\$context) = \@_;
        
        # Pre-deployment validation and setup
        print "  Preparing deployment for $name...\\n" if \$context->{verbose};
        
        # Check if terragrunt.hcl exists
        unless (-f 'terragrunt.hcl') {
            warn "  Warning: No terragrunt.hcl found in current directory\\n";
            return 0;
        }
        
        # Resource-specific pre-deployment checks could go here
        
        return 1;  # Success
    }
EOF
}

sub generate_post_deploy_hook {
    my $class = shift;
    my $config = shift;
    
    my $name = $config->{name};
    
    return <<EOF;
sub {
        my (\$context) = \@_;
        
        # Post-deployment tasks
        print "  Post-deployment tasks for $name...\\n" if \$context->{verbose};
        
        # Resource-specific post-deployment tasks could go here
        # e.g., health checks, validation, notifications
        
        return 1;  # Success
    }
EOF
}

sub generate_validate_hook {
    my $class = shift;
    my $config = shift;
    
    my $name = $config->{name};
    
    return <<EOF;
sub {
        my (\$context) = \@_;
        
        # Validation logic
        print "  Validating $name configuration...\\n" if \$context->{verbose};
        
        # Check basic requirements
        return -f 'terragrunt.hcl';
    }
EOF
}

sub generate_skip_hook {
    my $class = shift;
    my $config = shift;
    
    return <<EOF;
sub {
        my (\$context) = \@_;
        
        # Skip conditions - return 1 to skip deployment
        
        # Skip if already deployed and not forcing
        if (-f 'output.json' && !\$context->{force}) {
            print "  Already deployed (output.json exists)\\n" if \$context->{verbose};
            return 1;
        }
        
        # Resource-specific skip conditions could go here
        
        return 0;  # Don't skip
    }
EOF
}

# Helper functions to convert data structures to strings
sub _hash_to_string {
    my $hash = shift;
    return '{}' unless $hash && %$hash;
    
    my @pairs = map { "'$_' => '$hash->{$_}'" } keys %$hash;
    return '{ ' . join(', ', @pairs) . ' }';
}

sub _array_to_string {
    my $array = shift;
    return '[]' unless $array && @$array;
    
    my @quoted = map { "'$_'" } @$array;
    return '[ ' . join(', ', @quoted) . ' ]';
}

1;