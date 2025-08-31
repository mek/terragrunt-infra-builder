package Resource::Factory;
#
# Factory for creating Resource components
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use File::Spec;

# Create a resource object of the appropriate type
sub create_resource {
    my ($class, %args) = @_;
    
    my $resource_name = $args{name} || die "Resource name required";
    my $resource_type = $args{resource_type} || extract_resource_type($resource_name);
    my $template_dir = $args{template_dir} || die "Template directory required";
    
    # Try to load specific resource module
    my $module = load_resource_module($resource_type, $template_dir);
    
    if (!$module) {
        # Fall back to generic module
        $module = load_resource_module('generic', $template_dir);
        $args{resource_type} = $resource_type;  # Pass the intended type to generic
    }
    
    # Create and return resource object
    return $module->new(%args);
}

# Extract resource type from resource name
sub extract_resource_type {
    my $resource_name = shift;
    
    # Remove path components
    $resource_name =~ s/.*\///;
    
    # Enhanced AWS resource type mappings
    my %type_map = (
        # Compute
        'eks'             => 'eks',
        'ecs'             => 'ecs',
        'ec2'             => 'ec2',
        'lambda'          => 'lambda',
        'batch'           => 'batch',
        'lightsail'       => 'lightsail',
        
        # Networking
        'vpc'             => 'vpc',
        'external-vpc'    => 'external-vpc',
        'existing-vpc'    => 'external-vpc',
        'provided-vpc'    => 'external-vpc',
        'security-group'  => 'security-group',
        'sg'              => 'security-group',
        'alb'             => 'alb',
        'nlb'             => 'nlb',
        'clb'             => 'clb',
        'elb'             => 'elb',
        'nat-gateway'     => 'nat-gateway',
        'nat'             => 'nat-gateway',
        'internet-gateway' => 'internet-gateway',
        'igw'             => 'internet-gateway',
        'route53'         => 'route53',
        'cloudfront'      => 'cloudfront',
        'api-gateway'     => 'api-gateway',
        'apigw'           => 'api-gateway',
        
        # Storage
        's3'              => 's3',
        's3-backend'      => 's3-backend',
        'external-s3-backend' => 'external-s3-backend',
        'existing-s3-backend' => 'external-s3-backend',
        'provided-backend' => 'external-s3-backend',
        'external-backend' => 'external-s3-backend',
        'terraform-backend' => 's3-backend',
        'backend'         => 's3-backend',
        'state-bucket'    => 's3-backend',
        'efs'             => 'efs',
        'fsx'             => 'fsx',
        'ebs'             => 'ebs',
        'backup'          => 'backup',
        
        # Database
        'rds'             => 'rds-mysql',
        'rds-mysql'       => 'rds-mysql',
        'rds-postgres'    => 'rds-postgres',
        'rds-postgresql'  => 'rds-postgres',
        'mysql'           => 'rds-mysql',
        'postgres'        => 'rds-postgres',
        'postgresql'      => 'rds-postgres',
        'aurora'          => 'aurora',
        'aurora-mysql'    => 'aurora-mysql',
        'aurora-postgres' => 'aurora-postgres',
        'dynamodb'        => 'dynamodb',
        'ddb'             => 'dynamodb',
        'elasticache'     => 'elasticache',
        'elasticache-redis' => 'elasticache-redis',
        'elasticache-memcached' => 'elasticache-memcached',
        'redis'           => 'elasticache-redis',
        'memcached'       => 'elasticache-memcached',
        'documentdb'      => 'documentdb',
        'neptune'         => 'neptune',
        
        # Security & Identity
        'iam'             => 'iam',
        'iam-role'        => 'iam-role',
        'iam-policy'      => 'iam-policy',
        'iam-user'        => 'iam-user',
        'iam-group'       => 'iam-group',
        'role'            => 'iam-role',
        'policy'          => 'iam-policy',
        'user'            => 'iam-user',
        'group'           => 'iam-group',
        'kms'             => 'kms',
        'secrets-manager' => 'secrets-manager',
        'secrets'         => 'secrets-manager',
        'acm'             => 'acm',
        'waf'             => 'waf',
        'shield'          => 'shield',
        'guardduty'       => 'guardduty',
        
        # Container & Registry
        'ecr'             => 'ecr',
        'fargate'         => 'fargate',
        
        # Monitoring & Management
        'cloudwatch'      => 'cloudwatch',
        'cw'              => 'cloudwatch',
        'cloudtrail'      => 'cloudtrail',
        'sns'             => 'sns',
        'sqs'             => 'sqs',
        'eventbridge'     => 'eventbridge',
        'events'          => 'eventbridge',
        'ssm'             => 'ssm',
        
        # Analytics & ML
        'opensearch'      => 'opensearch',
        'elasticsearch'   => 'opensearch',
        'sagemaker'       => 'sagemaker',
        'emr'             => 'emr',
        'glue'            => 'glue',
        'athena'          => 'athena',
        'kinesis'         => 'kinesis',
        
        # DevOps
        'codebuild'       => 'codebuild',
        'codepipeline'    => 'codepipeline',
        'codecommit'      => 'codecommit',
        'codedeploy'      => 'codedeploy',
    );
    
    # Check for exact match
    return $type_map{$resource_name} if exists $type_map{$resource_name};
    
    # Check for partial match
    foreach my $key (keys %type_map) {
        if ($resource_name =~ /$key/i) {
            return $type_map{$key};
        }
    }
    
    # Return original name for unknown types, empty string for empty input
    return $resource_name;
}

# Load a resource module dynamically
sub load_resource_module {
    my ($resource_type, $template_dir) = @_;
    
    # Check if module exists in template directory
    my $module_file = "$template_dir/resources/$resource_type/Resource.pm";
    
    if (-f $module_file) {
        # Load the module
        eval {
            require $module_file;
        };
        
        if ($@) {
            warn "Failed to load module $module_file: $@\n";
            return undef;
        }
        
        # Return the module name
        my $module_name = "Resource::" . ucfirst($resource_type);
        $module_name =~ s/-([a-z])/\U$1/g;  # Convert kebab-case to CamelCase
        $module_name =~ s/^Resource::Eks$/Resource::EKS/;  # Special cases
        $module_name =~ s/^Resource::Rds$/Resource::RDS/;
        $module_name =~ s/^Resource::Iam$/Resource::IAM/;
        $module_name =~ s/^Resource::Vpc$/Resource::VPC/;
        $module_name =~ s/^Resource::Alb$/Resource::ALB/;
        $module_name =~ s/^Resource::Ecs$/Resource::ECS/;
        $module_name =~ s/^Resource::Ecr$/Resource::ECR/;
        $module_name =~ s/^Resource::S3$/Resource::S3/;
        
        print "  Loaded module: $module_name from $module_file\n" if $ENV{DEBUG};
        
        return $module_name;
    }
    
    return undef;
}

# List available resource types
sub list_resource_types {
    my ($template_dir) = @_;
    
    my @types;
    my $resources_dir = "$template_dir/resources";
    
    if (-d $resources_dir) {
        opendir(my $dh, $resources_dir) or die "Cannot open $resources_dir: $!";
        while (my $dir = readdir($dh)) {
            next if $dir =~ /^\./;
            next unless -d "$resources_dir/$dir";
            push @types, $dir;
        }
        closedir($dh);
    }
    
    return sort @types;
}

# Get all supported resource types (including aliases)
sub get_supported_resource_types {
    # Return the type mappings
    my %type_map = (
        # Compute
        'eks'             => 'eks',
        'ecs'             => 'ecs',
        'ec2'             => 'ec2',
        'lambda'          => 'lambda',
        'batch'           => 'batch',
        'lightsail'       => 'lightsail',
        
        # Networking
        'vpc'             => 'vpc',
        'external-vpc'    => 'external-vpc',
        'existing-vpc'    => 'external-vpc',
        'provided-vpc'    => 'external-vpc',
        'security-group'  => 'security-group',
        'sg'              => 'security-group',
        'alb'             => 'alb',
        'nlb'             => 'nlb',
        'clb'             => 'clb',
        'elb'             => 'elb',
        'nat-gateway'     => 'nat-gateway',
        'nat'             => 'nat-gateway',
        'internet-gateway' => 'internet-gateway',
        'igw'             => 'internet-gateway',
        'route53'         => 'route53',
        'cloudfront'      => 'cloudfront',
        'api-gateway'     => 'api-gateway',
        'apigw'           => 'api-gateway',
        
        # Storage
        's3'              => 's3',
        's3-backend'      => 's3-backend',
        'external-s3-backend' => 'external-s3-backend',
        'existing-s3-backend' => 'external-s3-backend',
        'provided-backend' => 'external-s3-backend',
        'external-backend' => 'external-s3-backend',
        'terraform-backend' => 's3-backend',
        'backend'         => 's3-backend',
        'state-bucket'    => 's3-backend',
        'efs'             => 'efs',
        'fsx'             => 'fsx',
        'ebs'             => 'ebs',
        'backup'          => 'backup',
        
        # Database
        'rds'             => 'rds-mysql',
        'rds-mysql'       => 'rds-mysql',
        'rds-postgres'    => 'rds-postgres',
        'rds-postgresql'  => 'rds-postgres',
        'mysql'           => 'rds-mysql',
        'postgres'        => 'rds-postgres',
        'postgresql'      => 'rds-postgres',
        'aurora'          => 'aurora',
        'aurora-mysql'    => 'aurora-mysql',
        'aurora-postgres' => 'aurora-postgres',
        'dynamodb'        => 'dynamodb',
        'ddb'             => 'dynamodb',
        'elasticache'     => 'elasticache',
        'elasticache-redis' => 'elasticache-redis',
        'elasticache-memcached' => 'elasticache-memcached',
        'redis'           => 'elasticache-redis',
        'memcached'       => 'elasticache-memcached',
        'documentdb'      => 'documentdb',
        'neptune'         => 'neptune',
        
        # Security & Identity
        'iam'             => 'iam',
        'iam-role'        => 'iam-role',
        'iam-policy'      => 'iam-policy',
        'iam-user'        => 'iam-user',
        'iam-group'       => 'iam-group',
        'role'            => 'iam-role',
        'policy'          => 'iam-policy',
        'user'            => 'iam-user',
        'group'           => 'iam-group',
        'kms'             => 'kms',
        'secrets-manager' => 'secrets-manager',
        'secrets'         => 'secrets-manager',
        'acm'             => 'acm',
        'waf'             => 'waf',
        'shield'          => 'shield',
        'guardduty'       => 'guardduty',
        
        # Container & Registry
        'ecr'             => 'ecr',
        'fargate'         => 'fargate',
        
        # Monitoring & Management
        'cloudwatch'      => 'cloudwatch',
        'cw'              => 'cloudwatch',
        'cloudtrail'      => 'cloudtrail',
        'sns'             => 'sns',
        'sqs'             => 'sqs',
        'eventbridge'     => 'eventbridge',
        'events'          => 'eventbridge',
        'ssm'             => 'ssm',
        
        # Analytics & ML
        'opensearch'      => 'opensearch',
        'elasticsearch'   => 'opensearch',
        'sagemaker'       => 'sagemaker',
        'emr'             => 'emr',
        'glue'            => 'glue',
        'athena'          => 'athena',
        'kinesis'         => 'kinesis',
        
        # DevOps
        'codebuild'       => 'codebuild',
        'codepipeline'    => 'codepipeline',
        'codecommit'      => 'codecommit',
        'codedeploy'      => 'codedeploy',
    );
    
    return %type_map;
}

# Get resource types by category
sub get_resource_types_by_category {
    my %categories = (
        compute => ['eks', 'ecs', 'ec2', 'lambda', 'batch', 'lightsail', 'fargate'],
        networking => ['vpc', 'external-vpc', 'security-group', 'alb', 'nlb', 'clb', 'elb', 'nat-gateway', 'internet-gateway', 'route53', 'cloudfront', 'api-gateway'],
        storage => ['s3', 's3-backend', 'external-s3-backend', 'efs', 'fsx', 'ebs', 'backup'],
        database => ['rds', 'rds-mysql', 'rds-postgres', 'aurora', 'aurora-mysql', 'aurora-postgres', 'dynamodb', 'elasticache', 'documentdb', 'neptune'],
        security => ['iam', 'iam-role', 'iam-policy', 'iam-user', 'iam-group', 'kms', 'secrets-manager', 'acm', 'waf', 'shield', 'guardduty'],
        container => ['ecr', 'ecs', 'eks', 'fargate'],
        monitoring => ['cloudwatch', 'cloudtrail', 'sns', 'sqs', 'eventbridge', 'ssm'],
        analytics => ['opensearch', 'sagemaker', 'emr', 'glue', 'athena', 'kinesis'],
        devops => ['codebuild', 'codepipeline', 'codecommit', 'codedeploy'],
    );
    
    return %categories;
}

# Suggest resource types based on partial input
sub suggest_resource_types {
    my ($input) = @_;
    $input = lc($input || '');
    
    my %type_map = get_supported_resource_types();
    my @suggestions;
    
    # Find exact matches first
    if (exists $type_map{$input}) {
        push @suggestions, $input;
    }
    
    # Find partial matches
    foreach my $type (keys %type_map) {
        if ($type =~ /\Q$input\E/i && $type ne $input) {
            push @suggestions, $type;
        }
    }
    
    return sort @suggestions;
}

# Get resource type from resource name (alias for extract_resource_type)
sub get_resource_type {
    my ($class, $resource_name) = @_;
    return extract_resource_type($resource_name);
}

# Get all available resource types
sub get_available_types {
    my ($class) = @_;
    my %type_map = get_supported_resource_types();
    return sort keys %type_map;
}

# Parse resource specification in name:type format
sub parse_resource_specification {
    my ($class, $specification) = @_;
    
    # Check if there's a colon at all
    if ($specification =~ /:/) {
        # Split on the first colon
        my ($name, $type_spec) = split(/:/, $specification, 2);
        
        # Handle empty type case
        if (defined $type_spec && $type_spec ne '') {
            # Resolve the type using extract_resource_type
            my $resolved_type = extract_resource_type($type_spec);
            return ($name, $resolved_type);
        } else {
            # Empty type part
            return ($name, '');
        }
    } else {
        # No colon found, just a name
        return ($specification, undef);
    }
}

1;
