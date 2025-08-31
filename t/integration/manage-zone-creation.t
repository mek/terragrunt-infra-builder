#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(dircopy);
use FindBin;
use Cwd qw(abs_path);

# Setup test environment
my $temp_dir = tempdir(CLEANUP => 1);
my $test_workspace = "$temp_dir/test_workspace";
my $original_dir = abs_path("$FindBin::Bin/../..");

# Copy necessary files to test workspace
make_path($test_workspace);
dircopy("$original_dir/lib", "$test_workspace/lib");
dircopy("$original_dir/admin", "$test_workspace/admin");

# Create a test version of manage.pl for integration testing
my $test_manage_pl = "$test_workspace/manage.pl";

subtest 'Setup test environment' => sub {
    plan tests => 4;
    
    ok(-d "$test_workspace/lib", 'lib directory copied');
    ok(-d "$test_workspace/admin", 'admin directory copied');
    
    # Create minimal manage-config.yaml for testing
    open my $config_fh, '>', "$test_workspace/admin/manage-config.yaml";
    print $config_fh <<'EOF';
zones:
  allowed:
    us-east-1a: "US East (N. Virginia) - AZ A"
    us-east-1b: "US East (N. Virginia) - AZ B"  
    us-east-1c: "US East (N. Virginia) - AZ C"
    us-west-2a: "US West (Oregon) - AZ A"
    us-west-2b: "US West (Oregon) - AZ B"
    us-west-2c: "US West (Oregon) - AZ C"
    eu-west-1a: "Europe (Ireland) - AZ A"
    eu-west-1b: "Europe (Ireland) - AZ B"
    eu-west-1c: "Europe (Ireland) - AZ C"

directories:
  environments: "envs"
  projects: "projects"
  templates: "admin/templates"
EOF
    close $config_fh;
    ok(-f "$test_workspace/admin/manage-config.yaml", 'manage-config.yaml created');
    
    # Create basic template structure
    make_path("$test_workspace/admin/templates/zone");
    open my $zone_template, '>', "$test_workspace/admin/templates/zone/terragrunt.hcl";
    print $zone_template <<'EOF';
# Zone: {{zone}}
# Environment: {{env_name}}
# Project: {{project_name}}
# Region: {{region_name}}

terraform {
  source = "git::https://github.com/example/terraform-modules.git//zone?ref=v1.0.0"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  zone = "{{zone}}"
  availability_zone = "{{availability_zone}}"
  environment = "{{env_name}}"
  project = "{{project_name}}"
  region = "{{region_name}}"
  
  {{zone_settings}}
  
  tags = {{common_tags}}
}
EOF
    close $zone_template;
    ok(-f "$test_workspace/admin/templates/zone/terragrunt.hcl", 'Zone template created');
};

# Create a simple test function to simulate manage.pl zone creation
sub test_zone_creation {
    my ($zone_name, $env_name, $region_name, $project_name) = @_;
    
    # Change to test workspace
    my $original_cwd = Cwd::getcwd();
    chdir $test_workspace;
    
    # Add lib to @INC for this test
    local @INC = ("$test_workspace/lib", @INC);
    
    # Load modules
    require Infrastructure::Factory;
    
    # Setup environment structure
    make_path("$test_workspace/envs/$env_name");
    if ($project_name) {
        make_path("$test_workspace/envs/$env_name/$project_name");
        make_path("$test_workspace/envs/$env_name/$project_name/$region_name");
    } else {
        make_path("$test_workspace/envs/$env_name/$region_name");
    }
    
    # Create zone
    my $zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => $zone_name,
        env_name => $env_name,
        region_name => $region_name,
        project_name => $project_name,
        workspace_root => $test_workspace,
        template_dir => "$test_workspace/admin/templates",
        dry_run => 0,
        verbose => 1,
    );
    
    # Validate and create
    $zone->validate();
    $zone->create();
    
    # Change back to original directory
    chdir $original_cwd;
    
    return $zone;
}

subtest 'Zone creation with project' => sub {
    plan tests => 4;
    
    my $zone = test_zone_creation('us-east-1a', 'testenv', 'us-east-1', 'testproject');
    
    isa_ok($zone, 'Infrastructure::Zone');
    is($zone->{name}, 'us-east-1a', 'Zone name is correct');
    is($zone->{project_name}, 'testproject', 'Project name is correct');
    
    my $expected_path = "$test_workspace/envs/testenv/testproject/us-east-1/us-east-1a";
    ok(-d $expected_path, 'Zone directory created in correct location with project');
};

subtest 'Zone creation without project' => sub {
    plan tests => 4;
    
    my $zone = test_zone_creation('eu-west-1a', 'prodenv', 'eu-west-1', undef);
    
    isa_ok($zone, 'Infrastructure::Zone');
    is($zone->{name}, 'eu-west-1a', 'Zone name is correct');
    is($zone->{project_name}, undef, 'Project name is undefined');
    
    my $expected_path = "$test_workspace/envs/prodenv/eu-west-1/eu-west-1a";
    ok(-d $expected_path, 'Zone directory created in correct location without project');
};

subtest 'Multiple zones in same region with project' => sub {
    plan tests => 6;
    
    my $zone_a = test_zone_creation('us-west-2a', 'multienv', 'us-west-2', 'multiproject');
    my $zone_b = test_zone_creation('us-west-2b', 'multienv', 'us-west-2', 'multiproject');
    my $zone_c = test_zone_creation('us-west-2c', 'multienv', 'us-west-2', 'multiproject');
    
    isa_ok($zone_a, 'Infrastructure::Zone');
    isa_ok($zone_b, 'Infrastructure::Zone');
    isa_ok($zone_c, 'Infrastructure::Zone');
    
    my $base_path = "$test_workspace/envs/multienv/multiproject/us-west-2";
    ok(-d "$base_path/us-west-2a", 'Zone A directory created');
    ok(-d "$base_path/us-west-2b", 'Zone B directory created');
    ok(-d "$base_path/us-west-2c", 'Zone C directory created');
};

subtest 'Zone terragrunt.hcl file creation and content' => sub {
    plan tests => 6;
    
    my $zone = test_zone_creation('us-east-1b', 'contenttest', 'us-east-1', 'contentproject');
    
    my $terragrunt_file = "$test_workspace/envs/contenttest/contentproject/us-east-1/us-east-1b/terragrunt.hcl";
    ok(-f $terragrunt_file, 'terragrunt.hcl file created');
    
    open my $fh, '<', $terragrunt_file;
    my $content = do { local $/; <$fh> };
    close $fh;
    
    like($content, qr/Zone: us-east-1b/, 'Zone name in template');
    like($content, qr/Environment: contenttest/, 'Environment name in template');
    like($content, qr/Project: contentproject/, 'Project name in template');
    like($content, qr/Region: us-east-1/, 'Region name in template');
    like($content, qr/availability_zone = "us-east-1b"/, 'Availability zone setting in template');
};

subtest 'Zone validation error handling' => sub {
    plan tests => 3;
    
    # Change to test workspace temporarily
    my $original_cwd = Cwd::getcwd();
    chdir $test_workspace;
    local @INC = ("$test_workspace/lib", @INC);
    require Infrastructure::Factory;
    
    # Test invalid zone name
    eval {
        my $invalid_zone = Infrastructure::Factory->create_infrastructure(
            type => 'zone',
            name => 'invalid-zone-name',
            env_name => 'testenv',
            region_name => 'us-east-1',
            workspace_root => $test_workspace,
            template_dir => "$test_workspace/admin/templates",
        );
        $invalid_zone->validate();
    };
    like($@, qr/Zone name must end with a letter/, 'Invalid zone name format fails validation');
    
    # Test zone name not matching region
    eval {
        my $mismatched_zone = Infrastructure::Factory->create_infrastructure(
            type => 'zone',
            name => 'us-west-2a',
            env_name => 'testenv', 
            region_name => 'us-east-1',
            workspace_root => $test_workspace,
            template_dir => "$test_workspace/admin/templates",
        );
        make_path("$test_workspace/envs/testenv/us-east-1");
        $mismatched_zone->validate();
    };
    like($@, qr/Zone name .* doesn't match region/, 'Zone name not matching region fails validation');
    
    # Test missing environment directory
    eval {
        my $no_env_zone = Infrastructure::Factory->create_infrastructure(
            type => 'zone',
            name => 'us-east-1a',
            env_name => 'nonexistent',
            region_name => 'us-east-1',
            workspace_root => $test_workspace,
            template_dir => "$test_workspace/admin/templates",
        );
        $no_env_zone->validate();
    };
    like($@, qr/Environment .* does not exist/, 'Non-existent environment fails validation');
    
    chdir $original_cwd;
};

subtest 'Zone template variables generation' => sub {
    plan tests => 7;
    
    # Change to test workspace
    my $original_cwd = Cwd::getcwd();
    chdir $test_workspace;
    local @INC = ("$test_workspace/lib", @INC);
    require Infrastructure::Factory;
    
    my $zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-east-1c',
        env_name => 'vartest',
        region_name => 'us-east-1',
        project_name => 'varproject',
        workspace_root => $test_workspace,
        template_dir => "$test_workspace/admin/templates",
    );
    
    my $vars = $zone->get_template_variables();

    is($vars->{zone}, 'us-east-1c', 'Zone variable');
    is($vars->{availability_zone}, 'us-east-1c', 'Availability zone variable');
    is($vars->{zone_region}, 'us-east-1', 'Zone region variable');
    is($vars->{zone_letter}, 'c', 'Zone letter variable');
    is($vars->{zone_letter_num}, 3, 'Zone letter number (c = 3)');
    like($vars->{zone_settings}, qr/private_subnet = "10\.0\.3\.0\/24"/, 'Private subnet calculation');
    like($vars->{common_tags}, qr/Project\s*=\s*"varproject"/, 'Project tag in common tags');
    
    chdir $original_cwd;
};

subtest 'Zone path generation edge cases' => sub {
    plan tests => 4;
    
    my $original_cwd = Cwd::getcwd();
    chdir $test_workspace;
    local @INC = ("$test_workspace/lib", @INC);
    require Infrastructure::Factory;
    
    # Test with all parameters
    my $full_zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-east-1a',
        env_name => 'fulltest',
        region_name => 'us-east-1',
        project_name => 'fullproject',
        workspace_root => $test_workspace,
        template_dir => "$test_workspace/admin/templates",
    );
    
    my $expected_full = "$test_workspace/envs/fulltest/fullproject/us-east-1/us-east-1a";
    is($full_zone->get_target_path(), $expected_full, 'Full path with all parameters');
    
    # Test without project
    my $no_project_zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-east-1a',
        env_name => 'noprojecttest',
        region_name => 'us-east-1',
        workspace_root => $test_workspace,
        template_dir => "$test_workspace/admin/templates",
    );
    
    my $expected_no_project = "$test_workspace/envs/noprojecttest/us-east-1/us-east-1a";
    is($no_project_zone->get_target_path(), $expected_no_project, 'Path without project');
    
    # Test without region
    my $no_region_zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-east-1a',
        env_name => 'noregiontest',
        project_name => 'noregionproject',
        workspace_root => $test_workspace,
        template_dir => "$test_workspace/admin/templates",
    );
    
    my $expected_no_region = "$test_workspace/envs/noregiontest/noregionproject/us-east-1a";
    is($no_region_zone->get_target_path(), $expected_no_region, 'Path without region');
    
    # Test with minimal parameters (only env and name)
    my $minimal_zone = Infrastructure::Factory->create_infrastructure(
        type => 'zone',
        name => 'us-east-1a',
        env_name => 'minimaltest',
        workspace_root => $test_workspace,
        template_dir => "$test_workspace/admin/templates",
    );
    
    my $expected_minimal = "$test_workspace/envs/minimaltest/us-east-1a";
    is($minimal_zone->get_target_path(), $expected_minimal, 'Path with minimal parameters');
    
    chdir $original_cwd;
};

done_testing();