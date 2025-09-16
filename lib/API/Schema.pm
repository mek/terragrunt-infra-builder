package API::Schema;

use strict;
use warnings;
use POSIX qw(strftime);
use JSON ();

# API Schema version for compatibility tracking
our $SCHEMA_VERSION = "1.0";

# Constructor - create a new API Schema object
sub new {
    my ($class, %args) = @_;
    my $self = bless {
        schema_version => $SCHEMA_VERSION,
        %args
    }, $class;
    return $self;
}

# Standardize resource metadata format for API consumption
sub create_resource_metadata {
    my ($class, %args) = @_;
    
    return {
        id => $args{path} || '',
        name => $args{name} || '',
        type => $args{type} || '',
        category => $args{category} || '',
        hierarchy => {
            environment => $args{env_name} || '',
            region => $args{region_name} || '',
            zone => $args{zone_name} || '',
            project => $args{project_name} || '',
        },
        path => {
            full => $args{path} || '',
            relative => $args{relative_path} || '',
        },
        naming => {
            full_name => $args{full_name} || '',
            short_name => $args{short_name} || '',
        },
        timestamps => {
            created => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
            updated => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
        },
    };
}

# Standardize deployment information
sub create_deployment_info {
    my ($class, %args) = @_;
    
    return {
        operation => $args{operation} || '',
        status => $args{success} ? 'success' : 'failed',
        timestamp => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
        execution_time => $args{execution_time} || 0,
        terragrunt_version => $args{terragrunt_version} || 'unknown',
        terraform_version => $args{terraform_version} || 'unknown',
        attempt => $args{attempt} || 1,
        max_attempts => $args{max_attempts} || 1,
    };
}

# Standardize terraform outputs format
sub normalize_terraform_outputs {
    my ($class, $raw_outputs) = @_;
    
    return {} unless $raw_outputs && ref($raw_outputs) eq 'HASH';
    
    my $normalized = {};
    
    foreach my $output_name (keys %$raw_outputs) {
        my $output = $raw_outputs->{$output_name};
        
        $normalized->{$output_name} = {
            value => $output->{value},
            type => $output->{type} || 'string',
            sensitive => $output->{sensitive} ? JSON::true : JSON::false,
            description => $output->{description} || '',
        };
    }
    
    return $normalized;
}

# Create complete API-ready resource document
sub create_resource_document {
    my ($class, %args) = @_;
    
    # Extract components
    my $metadata = $class->create_resource_metadata(%args);
    my $deployment = $class->create_deployment_info(%args);
    my $outputs = $class->normalize_terraform_outputs($args{raw_outputs});
    
    # Create comprehensive document
    my $document = {
        # API metadata
        schema_version => $SCHEMA_VERSION,
        document_type => 'terraform_resource',
        generated_at => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
        
        # Resource information
        resource => $metadata,
        
        # Deployment information
        deployment => $deployment,
        
        # Infrastructure outputs
        infrastructure => {
            outputs => $outputs,
            inputs_file => $args{path} ? "$args{path}/inputs.json" : '',
            terragrunt_file => $args{path} ? "$args{path}/terragrunt.hcl" : '',
        },
        
        # API endpoints (for future API server)
        _links => {
            self => {
                href => "/api/v1/resources/" . ($args{path} || ''),
                method => 'GET'
            },
            update => {
                href => "/api/v1/resources/" . ($args{path} || ''),
                method => 'PATCH'
            },
            delete => {
                href => "/api/v1/resources/" . ($args{path} || ''),
                method => 'DELETE'
            },
            deploy => {
                href => "/api/v1/resources/" . ($args{path} || '') . "/deploy",
                method => 'POST'
            },
            dependencies => {
                href => "/api/v1/resources/" . ($args{path} || '') . "/dependencies",
                method => 'GET'
            }
        }
    };
    
    return $document;
}

# Create deployment status document (for tracking ongoing deployments)
sub create_deployment_status {
    my ($class, %args) = @_;
    
    return {
        schema_version => $SCHEMA_VERSION,
        document_type => 'deployment_status',
        generated_at => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
        
        deployment => {
            id => $args{deployment_id} || generate_deployment_id(),
            status => $args{status} || 'pending',  # pending, running, success, failed
            progress => {
                current_step => $args{current_step} || 0,
                total_steps => $args{total_steps} || 1,
                percentage => $args{percentage} || 0,
            },
            resources => $args{resources} || [],
            started_at => $args{started_at} || strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
            completed_at => $args{completed_at} || undef,
            logs => $args{logs} || [],
        },
        
        _links => {
            self => {
                href => "/api/v1/deployments/" . ($args{deployment_id} || ''),
                method => 'GET'
            },
            cancel => {
                href => "/api/v1/deployments/" . ($args{deployment_id} || '') . "/cancel",
                method => 'POST'
            }
        }
    };
}

# Validate API document structure
sub validate_document {
    my ($class, $document) = @_;
    
    return 0 unless $document && ref($document) eq 'HASH';
    
    # Check required fields
    my @required_fields = qw(schema_version document_type generated_at);
    
    foreach my $field (@required_fields) {
        return 0 unless exists $document->{$field};
    }
    
    # Validate schema version
    return 0 unless $document->{schema_version} eq $SCHEMA_VERSION;
    
    # Document-type specific validation
    if ($document->{document_type} eq 'terraform_resource') {
        return 0 unless $document->{resource} && $document->{deployment};
    } elsif ($document->{document_type} eq 'deployment_status') {
        return 0 unless $document->{deployment};
    }
    
    return 1;
}

# Generate unique deployment ID
sub generate_deployment_id {
    my $timestamp = strftime("%Y%m%d_%H%M%S", gmtime());
    my $random = sprintf("%04x", rand(0xFFFF));
    return "deploy_${timestamp}_${random}";
}

# Validate schema structure and format
sub validate_schema {
    my ($class, $schema) = @_;
    return $class->validate_document($schema);
}

# Generate schema template
sub generate_schema {
    my ($class, %args) = @_;
    return $class->create_resource_document(%args);
}

# Get schema version
sub get_schema_version {
    my ($class) = @_;
    return $SCHEMA_VERSION;
}

# Convert document to JSON with consistent formatting
sub to_json {
    my ($class, $document) = @_;
    
    return JSON->new->pretty->canonical->encode($document);
}

# Parse JSON document with validation
sub from_json {
    my ($class, $json_string) = @_;
    
    my $document;
    eval {
        $document = JSON->new->decode($json_string);
    };
    
    return undef if $@;
    return undef unless $class->validate_document($document);
    
    return $document;
}

1;
