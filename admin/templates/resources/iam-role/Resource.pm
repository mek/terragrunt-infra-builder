package Resource::IamRole;

use strict;
use warnings;
use base 'Resource::Base';

# Generated: 2025-08-31 14:39:47
# Resource type: iam-role

# Constructor
sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    
    return $self;
}

# Override resource type
sub get_type {
    return 'iam-role';
}

# Override validation if needed
sub validate {
    my $self = shift;
    
    # Add iam-role-specific validation here
    # Examples:
    # - Check required parameters
    # - Validate resource naming conventions
    # - Verify dependencies exist
    
    return $self->SUPER::validate();
}

# Override post-creation hook if needed
sub post_create {
    my $self = shift;
    
    print "  iam-role resource created successfully\n" if $self->{verbose};
    
    # Add iam-role-specific post-creation tasks here
    # Examples:
    # - Generate additional configuration files
    # - Set up dependencies
    # - Create helper scripts
    
    return $self->SUPER::post_create();
}

# Add iam-role-specific methods here
# Examples:
# sub generate_kubeconfig { } # for EKS
# sub get_connection_string { } # for RDS
# sub get_load_balancer_dns { } # for ALB/NLB

1;
