#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 12;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use FindBin;

# Add lib to path
use lib "$FindBin::Bin/../../lib";

BEGIN {
    use_ok('Infrastructure::Factory');
}

# Create temporary workspace for testing
my $temp_dir = tempdir(CLEANUP => 1);
my $workspace_root = $temp_dir;
my $template_dir = "$FindBin::Bin/../../admin/templates";

# Setup basic environment structure
make_path("$workspace_root/envs/testenv");
make_path("$workspace_root/envs/testenv/testproject");

subtest 'Factory basic functionality' => sub {
    plan tests => 2;
    
    can_ok('Infrastructure::Factory', 'create_infrastructure');
    can_ok('Infrastructure::Factory', 'get_available_types');
};

subtest 'Create environment infrastructure' => sub {
    plan tests => 3;
    
    my $env = Infrastructure::Factory->create_infrastructure(
        type => 'environment',
        name => 'testenv',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($env, 'Infrastructure::Environment');
    is($env->get_type(), 'environment', 'Environment type is correct');
    is($env->{name}, 'testenv', 'Environment name is correct');
};

subtest 'Create project infrastructure' => sub {
    plan tests => 4;
    
    my $project = Infrastructure::Factory->create_infrastructure(
        type => 'project',
        name => 'testproject',
        env_name => 'testenv',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($project, 'Infrastructure::Project');
    is($project->get_type(), 'project', 'Project type is correct');
    is($project->{name}, 'testproject', 'Project name is correct');
    is($project->{env_name}, 'testenv', 'Project environment is correct');
};

subtest 'Create region infrastructure' => sub {
    plan tests => 5;
    
    my $region = Infrastructure::Factory->create_infrastructure(
        type => 'region',
        name => 'us-east-1',
        env_name => 'testenv',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($region, 'Infrastructure::Region');
    is($region->get_type(), 'region', 'Region type is correct');
    is($region->{name}, 'us-east-1', 'Region name is correct');
    is($region->{env_name}, 'testenv', 'Region environment is correct');
    is($region->{project_name}, 'testproject', 'Region project is correct');
};

subtest 'Create zone infrastructure' => sub {
    plan tests => 6;
    
    # Setup region directory first
    make_path("$workspace_root/envs/testenv/testproject/us-east-1");
    
    my $zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-east-1a',
        env_name => 'testenv',
        project_name => 'testproject',
        region_name => 'us-east-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($zone, 'Infrastructure::Zone');
    is($zone->get_type(), 'zone', 'Zone type is correct');
    is($zone->{name}, 'us-east-1a', 'Zone name is correct');
    is($zone->{env_name}, 'testenv', 'Zone environment is correct');
    is($zone->{project_name}, 'testproject', 'Zone project is correct');
    is($zone->{region_name}, 'us-east-1', 'Zone region is correct');
};

subtest 'Factory parameter validation' => sub {
    plan tests => 3;
    
    # Missing type
    eval {
        Infrastructure::Factory->create_infrastructure(
            name => 'test',
            workspace_root => $workspace_root,
            template_dir => $template_dir,
        );
    };
    like($@, qr/Type is required/, 'Missing type parameter fails');
    
    # Invalid type
    eval {
        Infrastructure::Factory->create_infrastructure(
            type => 'invalid_type',
            name => 'test',
            workspace_root => $workspace_root,
            template_dir => $template_dir,
        );
    };
    like($@, qr/Unknown infrastructure type/, 'Invalid type fails');
    
    # Missing name
    eval {
        Infrastructure::Factory->create_infrastructure(
            type => 'environment',
            workspace_root => $workspace_root,
            template_dir => $template_dir,
        );
    };
    like($@, qr/Name is required/, 'Missing name parameter fails');
};

subtest 'Get available infrastructure types' => sub {
    plan tests => 2;
    
    my @types = Infrastructure::Factory->get_available_types();
    
    ok(scalar(@types) > 0, 'Factory returns available types');
    
    my %type_hash = map { $_ => 1 } @types;
    ok(exists $type_hash{zone} && exists $type_hash{region} && 
       exists $type_hash{project} && exists $type_hash{environment}, 
       'Factory includes all expected infrastructure types');
};

subtest 'Factory with optional parameters' => sub {
    plan tests => 4;
    
    my $zone_minimal = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-west-1a',
        env_name => 'testenv',
        region_name => 'us-west-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
        dry_run => 1,
        verbose => 1,
    );
    
    isa_ok($zone_minimal, 'Infrastructure::Zone');
    is($zone_minimal->{dry_run}, 1, 'Dry run flag is set');
    is($zone_minimal->{verbose}, 1, 'Verbose flag is set');
    is($zone_minimal->{project_name}, undef, 'Project name is undefined when not provided');
};

subtest 'Multiple infrastructure creation with same factory' => sub {
    plan tests => 6;
    
    my $env1 = Infrastructure::Factory->create_infrastructure(
        type => 'environment',
        name => 'env1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my $env2 = Infrastructure::Factory->create_infrastructure(
        type => 'environment', 
        name => 'env2',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($env1, 'Infrastructure::Environment');
    isa_ok($env2, 'Infrastructure::Environment');
    is($env1->{name}, 'env1', 'First environment name is correct');
    is($env2->{name}, 'env2', 'Second environment name is correct');
    isnt($env1, $env2, 'Factory creates distinct objects');
    isnt($env1->{name}, $env2->{name}, 'Objects have different names');
};

subtest 'Factory inheritance and polymorphism' => sub {
    plan tests => 4;
    
    my @infra_objects = (
        Infrastructure::Factory->create_infrastructure(
            type => 'environment',
            name => 'testenv',
            workspace_root => $workspace_root,
            template_dir => $template_dir,
        ),
        Infrastructure::Factory->create_infrastructure(
            type => 'project',
            name => 'testproject',
            env_name => 'testenv',
            workspace_root => $workspace_root,
            template_dir => $template_dir,
        )
    );
    
    foreach my $obj (@infra_objects) {
        isa_ok($obj, 'Infrastructure::Base');
        can_ok($obj, 'get_type');
    }
};

done_testing();