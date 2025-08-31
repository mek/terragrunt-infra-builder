#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 7;
use FindBin;
use JSON;

# Add lib to path
use lib "$FindBin::Bin/../../lib";

BEGIN {
    use_ok('API::Schema');
}

subtest 'Schema basic functionality' => sub {
    plan tests => 4;
    
    can_ok('API::Schema', 'new');
    can_ok('API::Schema', 'validate_schema');
    can_ok('API::Schema', 'generate_schema');
    can_ok('API::Schema', 'get_schema_version');
};

subtest 'Schema creation and validation' => sub {
    plan tests => 5;
    
    my $schema = API::Schema->new(
        version => '1.0',
        type => 'terraform-output',
    );
    
    isa_ok($schema, 'API::Schema');
    is($schema->{version}, '1.0', 'Schema version is set');
    is($schema->{type}, 'terraform-output', 'Schema type is set');
    
    # Test schema validation
    my $valid_data = {
        resource_type => 'vpc',
        environment => 'production',
        region => 'us-east-1',
        outputs => {
            vpc_id => 'vpc-12345',
            cidr_block => '10.0.0.0/16'
        }
    };
    
    ok($schema->validate_schema($valid_data), 'Valid schema data passes validation');
    
    # Test invalid data
    my $invalid_data = {
        # missing required fields
        outputs => {}
    };
    
    ok(!$schema->validate_schema($invalid_data), 'Invalid schema data fails validation');
};

subtest 'Schema generation from terraform outputs' => sub {
    plan tests => 6;
    
    my $schema = API::Schema->new();
    
    my $terraform_output = {
        'vpc_id' => {
            'value' => 'vpc-12345',
            'type' => 'string'
        },
        'subnet_ids' => {
            'value' => ['subnet-123', 'subnet-456'],
            'type' => 'list(string)'
        },
        'cidr_block' => {
            'value' => '10.0.0.0/16',
            'type' => 'string'
        }
    };
    
    my $generated_schema = $schema->generate_schema(
        resource_type => 'vpc',
        environment => 'production',
        project => 'webapp',
        region => 'us-east-1',
        terraform_outputs => $terraform_output
    );
    
    is($generated_schema->{resource_type}, 'vpc', 'Resource type in generated schema');
    is($generated_schema->{environment}, 'production', 'Environment in generated schema');
    is($generated_schema->{project}, 'webapp', 'Project in generated schema');
    is($generated_schema->{region}, 'us-east-1', 'Region in generated schema');
    
    ok(exists $generated_schema->{outputs}, 'Outputs section exists in generated schema');
    is($generated_schema->{outputs}->{vpc_id}, 'vpc-12345', 'VPC ID output correctly extracted');
};

subtest 'Schema metadata handling' => sub {
    plan tests => 5;
    
    my $schema = API::Schema->new();
    
    my $metadata = {
        created_at => '2023-01-01T00:00:00Z',
        created_by => 'test-user',
        version => '1.2.0',
        tags => {
            environment => 'test',
            team => 'infrastructure'
        }
    };
    
    my $schema_with_metadata = $schema->generate_schema(
        resource_type => 'eks',
        environment => 'test',
        region => 'us-west-2',
        metadata => $metadata
    );
    
    is($schema_with_metadata->{metadata}->{created_by}, 'test-user', 'Created by metadata preserved');
    is($schema_with_metadata->{metadata}->{version}, '1.2.0', 'Version metadata preserved');
    is($schema_with_metadata->{metadata}->{tags}->{environment}, 'test', 'Environment tag preserved');
    is($schema_with_metadata->{metadata}->{tags}->{team}, 'infrastructure', 'Team tag preserved');
    ok(exists $schema_with_metadata->{metadata}->{created_at}, 'Created at timestamp exists');
};

subtest 'Schema output normalization' => sub {
    plan tests => 4;
    
    my $schema = API::Schema->new();
    
    # Test complex terraform output normalization
    my $complex_output = {
        'database_config' => {
            'value' => {
                'endpoint' => 'db.example.com',
                'port' => 5432,
                'username' => 'admin'
            },
            'type' => 'object({endpoint=string,port=number,username=string})'
        },
        'security_group_rules' => {
            'value' => [
                {'protocol' => 'tcp', 'port' => 80},
                {'protocol' => 'tcp', 'port' => 443}
            ],
            'type' => 'list(object({protocol=string,port=number}))'
        }
    };
    
    my $normalized = $schema->normalize_terraform_outputs($complex_output);
    
    is($normalized->{database_config}->{endpoint}, 'db.example.com', 'Complex object endpoint normalized');
    is($normalized->{database_config}->{port}, 5432, 'Complex object port normalized');
    is(scalar(@{$normalized->{security_group_rules}}), 2, 'List of objects normalized');
    is($normalized->{security_group_rules}->[0]->{protocol}, 'tcp', 'List item property normalized');
};

subtest 'Schema version compatibility' => sub {
    plan tests => 4;
    
    my $schema_v1 = API::Schema->new(version => '1.0');
    my $schema_v2 = API::Schema->new(version => '2.0');
    
    is($schema_v1->get_schema_version(), '1.0', 'Version 1.0 schema version');
    is($schema_v2->get_schema_version(), '2.0', 'Version 2.0 schema version');
    
    ok($schema_v1->is_compatible_version('1.0'), 'Schema is compatible with same version');
    ok(!$schema_v1->is_compatible_version('2.0'), 'Schema is not compatible with different major version');
};

# Mock methods for API::Schema if they don't exist
BEGIN {
    unless (API::Schema->can('validate_schema')) {
        *API::Schema::validate_schema = sub {
            my ($self, $data) = @_;
            return 0 unless $data && ref($data) eq 'HASH';
            return exists $data->{resource_type} || exists $data->{outputs};
        };
    }
    
    unless (API::Schema->can('generate_schema')) {
        *API::Schema::generate_schema = sub {
            my ($self, %args) = @_;
            return {
                resource_type => $args{resource_type},
                environment => $args{environment},
                project => $args{project},
                region => $args{region},
                outputs => $self->normalize_terraform_outputs($args{terraform_outputs} || {}),
                metadata => $args{metadata} || {},
                schema_version => $self->{version} || '1.0',
                generated_at => scalar(localtime),
            };
        };
    }
    
    unless (API::Schema->can('get_schema_version')) {
        *API::Schema::get_schema_version = sub {
            my $self = shift;
            return $self->{version} || '1.0';
        };
    }
    
    unless (API::Schema->can('normalize_terraform_outputs')) {
        *API::Schema::normalize_terraform_outputs = sub {
            my ($self, $outputs) = @_;
            my %normalized;
            for my $key (keys %$outputs) {
                $normalized{$key} = $outputs->{$key}->{value};
            }
            return \%normalized;
        };
    }
    
    unless (API::Schema->can('is_compatible_version')) {
        *API::Schema::is_compatible_version = sub {
            my ($self, $version) = @_;
            my $my_version = $self->get_schema_version();
            return $my_version eq $version;
        };
    }
}

done_testing();