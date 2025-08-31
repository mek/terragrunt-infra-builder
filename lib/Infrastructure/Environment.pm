package Infrastructure::Environment;

use strict;
use warnings;
use parent 'Infrastructure::Base';

sub get_type {
    return 'env';
}

# Environments are created at the top level
sub get_target_path {
    my $self = shift;
    return "$self->{workspace_root}/envs/$self->{name}";
}

# Environment-specific validation
sub validate {
    my $self = shift;
    
    # Check environment name format
    if ($self->{name} !~ /^[a-z0-9-]+$/) {
        die "Environment name must contain only lowercase letters, numbers, and hyphens\n";
    }
    
    # Check for reserved names
    my @reserved = qw(_global global admin templates modules);
    if (grep { $_ eq $self->{name} } @reserved) {
        die "Environment name '$self->{name}' is reserved\n";
    }
    
    return 1;
}

# Additional template variables for environments
sub get_template_variables {
    my $self = shift;

    my $vars = $self->SUPER::get_template_variables();

    # Environment-specific variables
    $vars->{environment} = $self->{name};

    # Environment type detection
    if ($self->{name} =~ /^(prod|production)$/i) {
        $vars->{env_type} = 'production';
        $vars->{is_production} = 'true';
    } elsif ($self->{name} =~ /^(staging|stage)$/i) {
        $vars->{env_type} = 'staging';
        $vars->{is_production} = 'false';
    } elsif ($self->{name} =~ /^(dev|development)$/i) {
        $vars->{env_type} = 'development';
        $vars->{is_production} = 'false';
    } elsif ($self->{name} =~ /^test/i) {
        $vars->{env_type} = 'testing';
        $vars->{is_production} = 'false';
    } else {
        $vars->{env_type} = 'custom';
        $vars->{is_production} = 'false';
    }

    # Common tags
    $vars->{common_tags} = qq|{
    Environment = "$self->{name}"
    ManagedBy   = "Terragrunt"
  }|;

    return $vars;
}

sub post_create {
    my $self = shift;

    if ($self->{verbose}) {
        my $vars = $self->get_template_variables();
        print "  Environment '$self->{name}' created\n";
        print "    Type: $vars->{env_type}\n";  # env_type
        print "    Path: " . $self->get_target_path() . "\n";
    }

    print "$Infrastructure::Base::GREEN✓ Environment $self->{name} created successfully$Infrastructure::Base::NC\n";
}

1;