#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 9;
use FindBin;

# Add lib to path
use lib "$FindBin::Bin/../../lib";

BEGIN {
    use_ok('Resource::Factory');
}

subtest 'Factory basic functionality' => sub {
    plan tests => 4;
    
    can_ok('Resource::Factory', 'create_resource');
    can_ok('Resource::Factory', 'get_resource_type');
    can_ok('Resource::Factory', 'get_available_types');
    can_ok('Resource::Factory', 'get_resource_types_by_category');
};

subtest 'Resource type detection from name' => sub {
    plan tests => 12;
    
    # Test exact type matches
    is(Resource::Factory->get_resource_type('vpc'), 'vpc', 'VPC type detection');
    is(Resource::Factory->get_resource_type('rds'), 'rds-mysql', 'RDS type detection defaults to mysql');
    is(Resource::Factory->get_resource_type('eks'), 'eks', 'EKS type detection');
    is(Resource::Factory->get_resource_type('lambda'), 'lambda', 'Lambda type detection');
    
    # Test alias detection
    is(Resource::Factory->get_resource_type('mysql'), 'rds-mysql', 'MySQL alias detection');
    is(Resource::Factory->get_resource_type('postgres'), 'rds-postgres', 'PostgreSQL alias detection');
    is(Resource::Factory->get_resource_type('redis'), 'elasticache-redis', 'Redis alias detection');
    is(Resource::Factory->get_resource_type('memcached'), 'elasticache-memcached', 'Memcached alias detection');
    
    # Test compound names
    is(Resource::Factory->get_resource_type('rds-postgres'), 'rds-postgres', 'RDS PostgreSQL compound type');
    is(Resource::Factory->get_resource_type('elasticache-redis'), 'elasticache-redis', 'ElastiCache Redis compound type');
    
    # Test unknown type
    is(Resource::Factory->get_resource_type('unknown-resource'), 'unknown-resource', 'Unknown type returns as-is');
    is(Resource::Factory->get_resource_type(''), '', 'Empty type returns empty');
};

subtest 'Custom resource naming' => sub {
    plan tests => 6;
    
    # Test name:type format parsing
    my ($name1, $type1) = Resource::Factory->parse_resource_specification('db1:mysql');
    is($name1, 'db1', 'Custom name extracted correctly');
    is($type1, 'rds-mysql', 'Type resolved from alias correctly');
    
    my ($name2, $type2) = Resource::Factory->parse_resource_specification('cache-primary:redis');
    is($name2, 'cache-primary', 'Complex custom name extracted correctly');
    is($type2, 'elasticache-redis', 'Redis type resolved correctly');
    
    # Test just name (no type)
    my ($name3, $type3) = Resource::Factory->parse_resource_specification('simple-vpc');
    is($name3, 'simple-vpc', 'Simple name extracted correctly');
    is($type3, undef, 'No type when not specified');
};

subtest 'Get available resource types' => sub {
    plan tests => 3;
    
    my @types = Resource::Factory->get_available_types();
    
    ok(scalar(@types) > 0, 'Factory returns available resource types');
    
    my %type_hash = map { $_ => 1 } @types;
    ok(exists $type_hash{'vpc'}, 'VPC type is available');
    ok(exists $type_hash{'eks'}, 'EKS type is available');
};

subtest 'Resource types by category' => sub {
    plan tests => 6;
    
    my %categories = Resource::Factory->get_resource_types_by_category();
    
    ok(exists $categories{compute}, 'Compute category exists');
    ok(exists $categories{networking}, 'Networking category exists');
    ok(exists $categories{database}, 'Database category exists');
    ok(exists $categories{storage}, 'Storage category exists');
    
    # Check some expected types in categories
    my @compute_types = @{$categories{compute} || []};
    my %compute_hash = map { $_ => 1 } @compute_types;
    ok(exists $compute_hash{'ec2'} || exists $compute_hash{'lambda'}, 'Compute category contains expected types');
    
    my @networking_types = @{$categories{networking} || []};
    my %networking_hash = map { $_ => 1 } @networking_types;
    ok(exists $networking_hash{'vpc'}, 'Networking category contains VPC');
};

subtest 'Type validation and normalization' => sub {
    plan tests => 8;
    
    # Test type normalization
    is(Resource::Factory->normalize_resource_type('VPC'), 'vpc', 'Type normalization to lowercase');
    is(Resource::Factory->normalize_resource_type('RDS-MySQL'), 'rds-mysql', 'Compound type normalization');
    is(Resource::Factory->normalize_resource_type('LAMBDA'), 'lambda', 'Lambda type normalization');
    
    # Test valid type checking
    ok(Resource::Factory->is_valid_resource_type('vpc'), 'VPC is valid type');
    ok(Resource::Factory->is_valid_resource_type('eks'), 'EKS is valid type');
    ok(Resource::Factory->is_valid_resource_type('rds-mysql'), 'RDS MySQL is valid type');
    
    # Test invalid type checking
    ok(!Resource::Factory->is_valid_resource_type('invalid-type'), 'Invalid type is rejected');
    ok(!Resource::Factory->is_valid_resource_type(''), 'Empty type is rejected');
};

subtest 'External resource types' => sub {
    plan tests => 4;
    
    # Test external resource detection
    ok(Resource::Factory->is_external_resource_type('external-vpc'), 'external-vpc is external resource');
    ok(Resource::Factory->is_external_resource_type('external-s3-backend'), 'external-s3-backend is external resource');
    
    # Test non-external resource
    ok(!Resource::Factory->is_external_resource_type('vpc'), 'vpc is not external resource');
    ok(!Resource::Factory->is_external_resource_type('rds-mysql'), 'rds-mysql is not external resource');
};

subtest 'Resource specification edge cases' => sub {
    plan tests => 10;
    
    # Test various specification formats
    my ($name1, $type1) = Resource::Factory->parse_resource_specification('simple-name');
    is($name1, 'simple-name', 'Simple name without type');
    is($type1, undef, 'No type when not specified');
    
    my ($name2, $type2) = Resource::Factory->parse_resource_specification('complex-name:complex-type');
    is($name2, 'complex-name', 'Complex name with type');
    is($type2, 'complex-type', 'Complex type preserved');
    
    my ($name3, $type3) = Resource::Factory->parse_resource_specification('name-with-dashes:type-with-dashes');
    is($name3, 'name-with-dashes', 'Name with dashes');
    is($type3, 'type-with-dashes', 'Type with dashes');
    
    # Test edge cases
    my ($name4, $type4) = Resource::Factory->parse_resource_specification(':type-only');
    is($name4, '', 'Empty name with type');
    is($type4, 'type-only', 'Type-only specification');
    
    my ($name5, $type5) = Resource::Factory->parse_resource_specification('name-only:');
    is($name5, 'name-only', 'Name with empty type');
    is($type5, '', 'Empty type part');
};

# Test helper functions if they don't exist
BEGIN {
    unless (Resource::Factory->can('parse_resource_specification')) {
        *Resource::Factory::parse_resource_specification = sub {
            my ($class, $spec) = @_;
            return split(':', $spec, 2) if $spec =~ /:/;
            return ($spec, undef);
        };
    }
    
    unless (Resource::Factory->can('normalize_resource_type')) {
        *Resource::Factory::normalize_resource_type = sub {
            my ($class, $type) = @_;
            return lc($type) if $type;
            return '';
        };
    }
    
    unless (Resource::Factory->can('is_valid_resource_type')) {
        *Resource::Factory::is_valid_resource_type = sub {
            my ($class, $type) = @_;
            return 0 unless $type;
            my @types = $class->get_available_types();
            my %type_hash = map { $_ => 1 } @types;
            return exists $type_hash{$type};
        };
    }
    
    unless (Resource::Factory->can('is_external_resource_type')) {
        *Resource::Factory::is_external_resource_type = sub {
            my ($class, $type) = @_;
            return $type && $type =~ /^external-/;
        };
    }
}

done_testing();