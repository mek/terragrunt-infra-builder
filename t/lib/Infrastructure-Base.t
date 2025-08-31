#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 8;
use File::Temp qw(tempdir);
use FindBin;

# Add lib to path
use lib "$FindBin::Bin/../../lib";

BEGIN {
    use_ok('Infrastructure::Base');
}

# Create temporary workspace for testing
my $temp_dir = tempdir(CLEANUP => 1);
my $workspace_root = $temp_dir;
my $template_dir = "$FindBin::Bin/../../admin/templates";

subtest 'Base class instantiation' => sub {
    plan tests => 6;
    
    my $base = Infrastructure::Base->new(
        name => 'test-infrastructure',
        env_name => 'testenv',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    isa_ok($base, 'Infrastructure::Base');
    is($base->{name}, 'test-infrastructure', 'Name property is correct');
    is($base->{env_name}, 'testenv', 'Environment name is correct');
    is($base->{workspace_root}, $workspace_root, 'Workspace root is correct');
    is($base->{template_dir}, $template_dir, 'Template directory is correct');
    is($base->get_type(), 'base', 'Base type is correct');
};

subtest 'Required methods exist' => sub {
    plan tests => 5;
    
    my $base = Infrastructure::Base->new(
        name => 'test',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    can_ok($base, 'new');
    can_ok($base, 'get_type');
    can_ok($base, 'get_target_path');
    can_ok($base, 'get_template_variables');
    can_ok($base, 'validate');
};

subtest 'Template variables generation' => sub {
    plan tests => 8;
    
    my $base = Infrastructure::Base->new(
        name => 'test-infra',
        env_name => 'production',
        project_name => 'webapp',
        region_name => 'us-west-2',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my %vars = $base->get_template_variables();
    
    is($vars{name}, 'test-infra', 'Name variable is correct');
    is($vars{env_name}, 'production', 'Environment name variable is correct');
    is($vars{project_name}, 'webapp', 'Project name variable is correct');
    is($vars{region_name}, 'us-west-2', 'Region name variable is correct');
    is($vars{workspace_root}, $workspace_root, 'Workspace root variable is correct');
    is($vars{template_dir}, $template_dir, 'Template directory variable is correct');
    
    # Check full_name construction
    like($vars{full_name}, qr/production/, 'Full name contains environment');
    like($vars{full_name}, qr/test-infra/, 'Full name contains resource name');
};

subtest 'Optional parameters handling' => sub {
    plan tests => 7;
    
    my $base = Infrastructure::Base->new(
        name => 'minimal-test',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
        dry_run => 1,
        verbose => 1,
        force => 1,
    );
    
    is($base->{name}, 'minimal-test', 'Name is set');
    is($base->{env_name}, undef, 'Environment name is undefined when not provided');
    is($base->{project_name}, undef, 'Project name is undefined when not provided');
    is($base->{region_name}, undef, 'Region name is undefined when not provided');
    is($base->{dry_run}, 1, 'Dry run flag is set');
    is($base->{verbose}, 1, 'Verbose flag is set');  
    is($base->{force}, 1, 'Force flag is set');
};

subtest 'Full name generation' => sub {
    plan tests => 4;
    
    # Test with all components
    my $full_base = Infrastructure::Base->new(
        name => 'resource',
        env_name => 'prod',
        project_name => 'api',
        region_name => 'us-east-1',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my %full_vars = $full_base->get_template_variables();
    like($full_vars{full_name}, qr/prod/, 'Full name includes environment');
    like($full_vars{full_name}, qr/api/, 'Full name includes project');
    like($full_vars{full_name}, qr/us-east-1/, 'Full name includes region');
    like($full_vars{full_name}, qr/resource/, 'Full name includes resource name');
};

subtest 'Default target path' => sub {
    plan tests => 2;
    
    my $base = Infrastructure::Base->new(
        name => 'test-path',
        env_name => 'testenv',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    my $target_path = $base->get_target_path();
    like($target_path, qr/\Q$workspace_root\E/, 'Target path contains workspace root');
    like($target_path, qr/test-path/, 'Target path contains resource name');
};

subtest 'Validation method' => sub {
    plan tests => 2;
    
    my $base = Infrastructure::Base->new(
        name => 'validation-test',
        workspace_root => $workspace_root,
        template_dir => $template_dir,
    );
    
    # Base validate should return true (no validation in base class)
    ok($base->validate(), 'Base validate method returns true');
    
    # Ensure validate is callable
    can_ok($base, 'validate');
};

done_testing();