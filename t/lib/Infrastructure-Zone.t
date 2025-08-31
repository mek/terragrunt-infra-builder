#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 18;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use FindBin;

# Add lib to path
use lib "$FindBin::Bin/../../lib";

BEGIN {
    use_ok('Infrastructure::Zone');
    use_ok('Infrastructure::Factory');
}

# Create temporary workspace for testing
my $temp_dir = tempdir(CLEANUP => 1);
my $workspace_root = $temp_dir;
my $template_dir = "$FindBin::Bin/../../admin/templates";

# Setup basic environment structure
make_path("$workspace_root/envs/testenv");
make_path("$workspace_root/envs/testenv/testproject");
make_path("$workspace_root/envs/testenv/testproject/us-east-1");

subtest 'Zone object creation and basic properties' => sub {
    plan tests => 6;
    
    my $zone = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'testenv',
        region_name => 'us-east-1',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($zone, 'Infrastructure::Zone');
    is($zone->get_type(), 'zone', 'Zone type is correct');
    is($zone->{name}, 'us-east-1a', 'Zone name is correct');
    is($zone->{env_name}, 'testenv', 'Environment name is correct');
    is($zone->{region_name}, 'us-east-1', 'Region name is correct');
    is($zone->{project_name}, 'testproject', 'Project name is correct');
};

subtest 'Zone target path generation' => sub {
    plan tests => 3;
    
    # Test with project
    my $zone_with_project = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'testenv',
        region_name => 'us-east-1',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my $expected_path = "$workspace_root/envs/testenv/testproject/us-east-1/us-east-1a";
    is($zone_with_project->get_target_path(), $expected_path, 'Target path with project is correct');
    
    # Test without project
    my $zone_without_project = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'testenv',
        region_name => 'us-east-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my $expected_path_no_project = "$workspace_root/envs/testenv/us-east-1/us-east-1a";
    is($zone_without_project->get_target_path(), $expected_path_no_project, 'Target path without project is correct');
    
    # Test with only environment
    my $zone_env_only = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'testenv',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my $expected_path_env_only = "$workspace_root/envs/testenv/us-east-1a";
    is($zone_env_only->get_target_path(), $expected_path_env_only, 'Target path with environment only is correct');
};

subtest 'Zone validation tests' => sub {
    plan tests => 6;
    
    # Valid zone
    my $valid_zone = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'testenv',
        region_name => 'us-east-1',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    eval { $valid_zone->validate() };
    ok(!$@, 'Valid zone passes validation');
    
    # Missing environment
    my $no_env_zone = Infrastructure::Zone->new(
        name => 'us-east-1a',
        region_name => 'us-east-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    eval { $no_env_zone->validate() };
    ok($@, 'Zone without environment fails validation');
    
    # Missing region
    my $no_region_zone = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'testenv',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    eval { $no_region_zone->validate() };
    ok($@, 'Zone without region fails validation');
    
    # Invalid zone name format
    my $invalid_name_zone = Infrastructure::Zone->new(
        name => 'invalid-zone',
        env_name => 'testenv',
        region_name => 'us-east-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    eval { $invalid_name_zone->validate() };
    ok($@, 'Zone with invalid name format fails validation');
    
    # Zone name doesn't match region
    my $mismatched_zone = Infrastructure::Zone->new(
        name => 'us-west-2a',
        env_name => 'testenv',
        region_name => 'us-east-1',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    eval { $mismatched_zone->validate() };
    ok($@, 'Zone name not matching region fails validation');
    
    # Non-existent environment
    my $nonexistent_env_zone = Infrastructure::Zone->new(
        name => 'us-east-1a',
        env_name => 'nonexistent',
        region_name => 'us-east-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    eval { $nonexistent_env_zone->validate() };
    ok($@, 'Zone with non-existent environment fails validation');
};

subtest 'Zone template variables' => sub {
    plan tests => 8;
    
    my $zone = Infrastructure::Zone->new(
        name => 'us-east-1b',
        env_name => 'testenv',
        region_name => 'us-east-1',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my $vars = $zone->get_template_variables();

    is($vars->{zone}, 'us-east-1b', 'Zone variable is correct');
    is($vars->{availability_zone}, 'us-east-1b', 'Availability zone variable is correct');
    is($vars->{zone_region}, 'us-east-1', 'Zone region variable is correct');
    is($vars->{zone_letter}, 'b', 'Zone letter variable is correct');
    is($vars->{zone_letter_num}, 2, 'Zone letter number is correct (b = 2)');

    like($vars->{zone_settings}, qr/availability_zone = "us-east-1b"/, 'Zone settings contain availability zone');
    like($vars->{zone_settings}, qr/private_subnet = "10\.0\.2\.0\/24"/, 'Zone settings contain correct private subnet');
    like($vars->{common_tags}, qr/Zone\s*=\s*"us-east-1b"/, 'Common tags contain zone');
};

subtest 'Factory creation of zones' => sub {
    plan tests => 3;
    
    my $zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-west-2c',
        env_name => 'testenv',
        region_name => 'us-west-2',
        project_name => 'testproject',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($zone, 'Infrastructure::Zone');
    is($zone->{name}, 'us-west-2c', 'Factory created zone has correct name');
    is($zone->{project_name}, 'testproject', 'Factory created zone has correct project');
};

done_testing();
