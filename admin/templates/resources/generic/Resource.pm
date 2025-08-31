package Resource::Generic;

use strict;
use warnings;
use base 'Resource::Base';

# Generated: 2025-08-31 14:40:00
# Resource type: generic (fallback for unknown resource types)

# Constructor
sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    
    return $self;
}

# Override resource type - use the passed resource_type or generic
sub get_type {
    my $self = shift;
    return $self->{resource_type} || 'generic';
}

# Override validation if needed
sub validate {
    my $self = shift;
    
    # Add generic validation here
    # Examples:
    # - Check required parameters
    # - Validate resource naming conventions
    # - Verify dependencies exist
    
    return $self->SUPER::validate();
}

# Override post-creation hook if needed
sub post_create {
    my $self = shift;
    
    my $type = $self->get_type();
    print "  $type resource created successfully\n" if $self->{verbose};
    
    # Add generic post-creation tasks here
    # Examples:
    # - Generate additional configuration files
    # - Set up dependencies
    # - Create helper scripts
    
    return $self->SUPER::post_create();
}

# Add generic methods here
# Examples:
# sub generate_kubeconfig { } # for EKS
# sub get_connection_string { } # for RDS
# sub get_load_balancer_dns { } # for ALB/NLB

1;