package Resource::SecurityGroup;

use strict;
use warnings;
use base 'Resource::Base';

# Generated: 2025-08-31 14:39:50
# Resource type: security-group

# Constructor
sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    
    return $self;
}

# Override resource type
sub get_type {
    return 'security-group';
}

# Override validation if needed
sub validate {
    my $self = shift;
    
    # Add security-group-specific validation here
    # Examples:
    # - Check required parameters
    # - Validate resource naming conventions
    # - Verify dependencies exist
    
    return $self->SUPER::validate();
}

# Override post-creation hook if needed
sub post_create {
    my $self = shift;
    
    print "  security-group resource created successfully\n" if $self->{verbose};
    
    # Add security-group-specific post-creation tasks here
    # Examples:
    # - Generate additional configuration files
    # - Set up dependencies
    # - Create helper scripts
    
    return $self->SUPER::post_create();
}

# Add security-group-specific methods here
# Examples:
# sub generate_kubeconfig { } # for EKS
# sub get_connection_string { } # for RDS
# sub get_load_balancer_dns { } # for ALB/NLB

1;
