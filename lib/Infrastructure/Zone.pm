package Infrastructure::Zone;

use strict;
use warnings;
use parent 'Infrastructure::Base';

sub get_type {
    return 'zone';
}

# Zones are created under regions (potentially under environments and projects)
sub get_target_path {
    my $self = shift;
    
    my $base = "$self->{workspace_root}/envs/$self->{env_name}";
    
    # Add project if specified
    if ($self->{project_name}) {
        $base .= "/$self->{project_name}";
    }
    
    # Add region if specified
    if ($self->{region_name}) {
        $base .= "/$self->{region_name}";
    }
    
    return "$base/$self->{name}";
}

# Zone-specific validation
sub validate {
    my $self = shift;
    
    # Check that environment is provided
    if (!$self->{env_name}) {
        die "Environment name is required for zone creation\n";
    }
    
    # Check that region is provided
    if (!$self->{region_name}) {
        die "Region name is required for zone creation\n";
    }
    
    # Check zone name format first (availability zone format like us-east-1a)
    if ($self->{name} !~ /^[a-z0-9]+-[a-z0-9]+-[0-9]+[a-z]$/) {
        die "Zone name must end with a letter\n";
    }
    
    # Validate that zone matches the region (only if format is correct)
    my $region_part = $self->{name};
    $region_part =~ s/[a-z]$//;  # Remove the last letter
    if ($region_part ne $self->{region_name}) {
        die "Zone name '$self->{name}' doesn't match region '$self->{region_name}'\n";
    }
    
    # Check if environment exists
    my $env_path = "$self->{workspace_root}/envs/$self->{env_name}";
    if (!-d $env_path) {
        die "Environment '$self->{env_name}' does not exist. Create it first.\n";
    }
    
    # Check if region exists
    my $region_path = $env_path;
    if ($self->{project_name}) {
        $region_path .= "/$self->{project_name}";
    }
    $region_path .= "/$self->{region_name}";
    if (!-d $region_path) {
        die "Region '$self->{region_name}' does not exist. Create it first.\n";
    }
    
    return 1;
}

# Additional template variables for zones
sub get_template_variables {
    my $self = shift;

    my $vars = $self->SUPER::get_template_variables();

    # Zone-specific variables
    $vars->{zone} = $self->{name};
    $vars->{availability_zone} = $self->{name};

    # Extract zone info
    if ($self->{name} =~ /^(.+)([a-z])$/) {
        $vars->{zone_region} = $1;      # us-east-1
        $vars->{zone_letter} = $2;      # a, b, c, etc.
    }

    # Convert zone letter to number for subnet calculations
    my $letter = $vars->{zone_letter} || 'a';
    $vars->{zone_letter_num} = ord(lc($letter)) - ord('a') + 1;

    # Zone-specific settings
    $vars->{zone_settings} = qq|{
    # Availability zone
    availability_zone = "$self->{name}"

    # Subnet configuration for this AZ
    private_subnet = "10.0.$vars->{zone_letter_num}.0/24"
    public_subnet  = "10.0.10$vars->{zone_letter_num}.0/24"

    # Zone-specific instance settings
    preferred_instance_types = ["t3.micro", "t3.small", "t3.medium"]

    # Storage settings
    ebs_optimized = true
    volume_type = "gp3"
  }|;

    # Update zone_settings with calculated subnet values
    $vars->{zone_settings} = qq|{
    # Availability zone
    availability_zone = "$self->{name}"

    # Subnet configuration for this AZ
    private_subnet = "10.0.$vars->{zone_letter_num}.0/24"
    public_subnet  = "10.0.10$vars->{zone_letter_num}.0/24"

    # Zone-specific instance settings
    preferred_instance_types = ["t3.micro", "t3.small", "t3.medium"]

    # Storage settings
    ebs_optimized = true
    volume_type = "gp3"
  }|;

    # Common tags
    $vars->{common_tags} = qq|{
    Zone        = "$self->{name}"
    Region      = "$self->{region_name}"
    Environment = "$self->{env_name}"|;

    if ($self->{project_name}) {
        $vars->{common_tags} .= qq|\n    Project     = "$self->{project_name}"|;
    }

    $vars->{common_tags} .= qq|\n    ManagedBy   = "Terragrunt"
  }|;

    return $vars;
}

sub post_create {
    my $self = shift;
    
    if ($self->{verbose}) {
        print "  Zone '$self->{name}' created in region '$self->{region_name}'\n";
        print "    Environment: $self->{env_name}\n";
        if ($self->{project_name}) {
            print "    Project: $self->{project_name}\n";
        }
        print "    Path: " . $self->get_target_path() . "\n";
    }
    
    print "$Infrastructure::Base::GREEN✓ Zone $self->{name} created successfully$Infrastructure::Base::NC\n";
}

1;
