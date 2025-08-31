package Infrastructure::Region;

use strict;
use warnings;
use parent 'Infrastructure::Base';

sub get_type {
    return 'region';
}

# Regions are created under environments (potentially under projects)
sub get_target_path {
    my $self = shift;
    
    my $base = "$self->{workspace_root}/envs/$self->{env_name}";
    
    # Add project if specified
    if ($self->{project_name}) {
        $base .= "/$self->{project_name}";
    }
    
    return "$base/$self->{name}";
}

# Region-specific validation
sub validate {
    my $self = shift;
    
    # Check that environment is provided
    if (!$self->{env_name}) {
        die "Environment name is required for region creation\n";
    }
    
    # Check region name format (AWS region format)
    if ($self->{name} !~ /^[a-z0-9-]+$/) {
        die "Region name must contain only lowercase letters, numbers, and hyphens\n";
    }
    
    # Validate AWS region format
    if ($self->{name} !~ /^(us|eu|ap|ca|sa|af|me)-[a-z]+-\d+$/) {
        print "  Warning: Region name doesn't follow AWS format (us-east-1, eu-west-1, etc.)\n" if $self->{verbose};
    }
    
    # Check if environment exists
    my $env_path = "$self->{workspace_root}/envs/$self->{env_name}";
    if (!-d $env_path) {
        die "Environment '$self->{env_name}' does not exist. Create it first.\n";
    }
    
    return 1;
}

# Additional template variables for regions
sub get_template_variables {
    my $self = shift;
    
    my %vars = $self->SUPER::get_template_variables();
    
    # Region-specific variables
    $vars{aws_region} = $self->{name};
    $vars{region} = $self->{name};
    
    # Extract region info
    if ($self->{name} =~ /^([a-z]+)-([a-z]+)-(\d+)$/) {
        $vars{region_continent} = $1;  # us, eu, ap, etc.
        $vars{region_location} = $2;   # east, west, central, etc.
        $vars{region_number} = $3;     # 1, 2, 3, etc.
    }
    
    # Availability zones (common pattern)
    my @azs = ($self->{name}."a", $self->{name}."b", $self->{name}."c");
    $vars{availability_zones} = '["' . join('", "', @azs) . '"]';
    
    # Region-specific settings
    $vars{region_settings} = qq|{
    # Availability zones
    azs = $vars{availability_zones}
    
    # Default VPC CIDR (can be overridden)
    vpc_cidr = "10.0.0.0/16"
    
    # Subnets
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    
    # NAT Gateway settings
    enable_nat_gateway = true
    single_nat_gateway = false
  }|;
    
    # Common tags
    $vars{common_tags} = qq|{
    Region    = "$self->{name}"
    Environment = "$self->{env_name}"
    ManagedBy = "Terragrunt"
  }|;
    
    return %vars;
}

sub post_create {
    my $self = shift;
    
    if ($self->{verbose}) {
        print "  Region '$self->{name}' created for environment '$self->{env_name}'\n";
        if ($self->{project_name}) {
            print "    Project: $self->{project_name}\n";
        }
        print "    Path: " . $self->get_target_path() . "\n";
    }
    
    print "$Infrastructure::Base::GREEN✓ Region $self->{name} created successfully$Infrastructure::Base::NC\n";
}

1;