package Infrastructure::Project;

use strict;
use warnings;
use parent 'Infrastructure::Base';

sub get_type {
    return 'project';
}

# Projects are created under the projects directory
sub get_target_path {
    my $self = shift;
    return "$self->{workspace_root}/projects/$self->{name}";
}

# Project-specific validation
sub validate {
    my $self = shift;

    # Check project name format
    if ( $self->{name} !~ /^[a-z0-9-]+$/ ) {
        die
"Project name must contain only lowercase letters, numbers, and hyphens\n";
    }

    # Check for reserved names
    my @reserved = qw(_global global admin templates modules envs);
    if ( grep { $_ eq $self->{name} } @reserved ) {
        die "Project name '$self->{name}' is reserved\n";
    }

    return 1;
}

# Additional template variables for projects
sub get_template_variables {
    my $self = shift;

    my $vars = $self->SUPER::get_template_variables();

    # Project-specific variables
    $vars->{project} = $self->{name};

    # Project type detection based on name
    if ( $self->{name} =~ /^(api|backend|service)/ ) {
        $vars->{project_type} = 'backend';
    }
    elsif ( $self->{name} =~ /^(web|frontend|ui|app)/ ) {
        $vars->{project_type} = 'frontend';
    }
    elsif ( $self->{name} =~ /^(data|analytics|ml|ai)/ ) {
        $vars->{project_type} = 'data';
    }
    elsif ( $self->{name} =~ /^(infra|infrastructure|platform)/ ) {
        $vars->{project_type} = 'infrastructure';
    }
    else {
        $vars->{project_type} = 'application';
    }

    # Default resource settings based on project type
    my %type_settings = (
        'backend' => {
            default_instance  => 't3.medium',
            min_instances     => 2,
            enable_monitoring => 'true',
            enable_scaling    => 'true'
        },
        'frontend' => {
            default_instance  => 't3.micro',
            min_instances     => 1,
            enable_monitoring => 'false',
            enable_scaling    => 'false'
        },
        'data' => {
            default_instance  => 'm5.large',
            min_instances     => 1,
            enable_monitoring => 'true',
            enable_scaling    => 'true'
        },
        'infrastructure' => {
            default_instance  => 't3.small',
            min_instances     => 1,
            enable_monitoring => 'true',
            enable_scaling    => 'false'
        },
        'application' => {
            default_instance  => 't3.small',
            min_instances     => 2,
            enable_monitoring => 'true',
            enable_scaling    => 'true'
        }
    );

    my $settings =
      $type_settings{ $vars->{project_type} } || $type_settings{'application'};
    foreach my $key ( keys %$settings ) {
        $vars->{$key} = $settings->{$key};
    }

    # Common tags
    $vars->{common_tags} = qq|{
    Project   = "$self->{name}"
    Type      = "$vars->{project_type}"
    ManagedBy = "Terragrunt"
  }|;

    return $vars;
}

sub post_create {
    my $self = shift;

    if ( $self->{verbose} ) {
        my $vars = $self->get_template_variables();
        print "  Project '$self->{name}' created\n";
        print "    Type: $vars->{project_type}\n";
        print "    Path: " . $self->get_target_path() . "\n";
    }

    print
"$Infrastructure::Base::GREEN✓ Project $self->{name} created successfully$Infrastructure::Base::NC\n";
}

1;
