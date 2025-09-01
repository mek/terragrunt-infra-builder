package Infrastructure::Base;
#
# Base class for Infrastructure components
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use File::Path qw(make_path);
use File::Copy qw(copy);
use File::Basename;

# Color codes for output
our $GREEN = "\033[0;32m";
our $YELLOW = "\033[0;33m";
our $RED = "\033[0;31m";
our $BLUE = "\033[0;34m";
our $CYAN = "\033[0;36m";
our $MAGENTA = "\033[0;35m";
our $BOLD = "\033[1m";
our $NC = "\033[0m"; # No Color

# Base class for Environment, Project, Region, Zone creation

# Constructor
sub new {
    my ($class, %args) = @_;
    
    my $self = {};
    
    # Required parameters
    $self->{name}           = $args{name} or die "Name required";
    $self->{workspace_root} = $args{workspace_root} or die "Workspace root required";
    $self->{template_dir}   = $args{template_dir} or die "Template directory required";
    
    # Parameters with defaults
    $self->{dry_run} = $args{dry_run} || 0;
    $self->{verbose} = $args{verbose} || 0;
    $self->{force}   = $args{force} || 0;
    $self->{envs_base} = $args{envs_base} || "envs";
    $self->{projects_base} = $args{projects_base} || "projects";
    $self->{structure_ordering} = $args{structure_ordering} || "environment_first";
    
    # Optional parameters (different for each type)
    $self->{env_name}    = $args{env_name} if defined $args{env_name};
    $self->{project_name} = $args{project_name} if defined $args{project_name};
    $self->{region_name}  = $args{region_name} if defined $args{region_name};
    $self->{zone_name}    = $args{zone_name} if defined $args{zone_name};
    
    bless $self, $class;
    return $self;
}

# Get the infrastructure type (override in subclasses)
sub get_type {
    my $self = shift;
    my $class = ref($self);
    $class =~ s/.*:://;
    return lc($class);
}

# Get the template directory for this infrastructure type
sub get_template_dir {
    my $self = shift;
    my $type = $self->get_type();
    return "$self->{template_dir}/$type";
}

# Get the target directory path (override in subclasses)
sub get_target_path {
    my $self = shift;
    die "get_target_path must be implemented by subclass";
}

# Get the primary config file name (env.hcl, project.hcl, etc.)
sub get_config_filename {
    my $self = shift;
    my $type = $self->get_type();
    return "$type.hcl";
}

# Pre-creation validation hook (override in subclasses if needed)
sub validate {
    my $self = shift;
    return 1;  # Default: always valid
}

# Pre-creation hook (override in subclasses if needed)
sub pre_create {
    my $self = shift;
    # Default: do nothing
}

# Post-creation hook (override in subclasses if needed)
sub post_create {
    my $self = shift;
    if ($self->{verbose}) {
        my $type = ucfirst($self->get_type());
        print "  $type '$self->{name}' created successfully\n";
    }
}

# Get template variables for substitution
sub get_template_variables {
    my $self = shift;
    
    # Build full name from components
    my $full_name = $self->_build_full_name();
    
    my %vars = (
        name           => $self->{name} || '',
        env_name       => $self->{env_name} || '',
        project_name   => $self->{project_name} || '',
        region_name    => $self->{region_name} || '',
        zone_name      => $self->{zone_name} || '',
        workspace_root => $self->{workspace_root} || '',
        template_dir   => $self->{template_dir} || '',
        full_name      => $full_name,
    );

    return \%vars;
}

# Build full name from available components
sub _build_full_name {
    my $self = shift;
    
    my @parts;
    push @parts, $self->{env_name} if $self->{env_name};
    push @parts, $self->{project_name} if $self->{project_name};
    push @parts, $self->{region_name} if $self->{region_name};
    push @parts, $self->{zone_name} if $self->{zone_name};
    push @parts, $self->{name} if $self->{name};
    
    return join('-', @parts);
}

# Process template file
sub process_template {
    my ($self, $template_file, $output_file) = @_;
    
    # Read template
    open(my $in_fh, '<', $template_file) or die "Cannot read $template_file: $!";
    my $content = do { local $/; <$in_fh> };
    close $in_fh;
    
    # Get variables
    my $vars = $self->get_template_variables();

    # Replace variables
    foreach my $key (keys %{$vars}) {
        my $value = $vars->{$key};
        $content =~ s/\{\{$key\}\}/$value/g;
    }
    
    # Write output
    open(my $out_fh, '>', $output_file) or die "Cannot write $output_file: $!";
    print $out_fh $content;
    close $out_fh;
}

# Copy template directory to target directory
sub copy_template_dir {
    my $self = shift;
    
    my $template_dir = $self->get_template_dir();
    my $target_path = $self->get_target_path();
    
    if (!-d $template_dir) {
        die "Template directory not found: $template_dir\n";
    }
    
    # Create target directory
    make_path($target_path) unless $self->{dry_run};
    
    # Copy all files from template directory
    opendir(my $dh, $template_dir) or die "Cannot open $template_dir: $!";
    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;
        next if $file =~ /\.pm$/;  # Skip Perl modules
        
        my $src = "$template_dir/$file";
        my $dst = "$target_path/$file";
        
        if (-f $src) {
            if ($file =~ /\.hcl$/) {
                # Process HCL template files
                $self->process_template($src, $dst) unless $self->{dry_run};
            } else {
                # Copy other files as-is
                copy($src, $dst) unless $self->{dry_run};
            }
        }
    }
    closedir($dh);
}

# Main method to create the infrastructure component
sub create {
    my $self = shift;
    
    my $target_path = $self->get_target_path();
    my $type = ucfirst($self->get_type());
    
    print "${CYAN}Adding $type: $self->{name}${NC}\n";
    
    # Check if already exists
    if (-d $target_path && !$self->{force} && !$self->{dry_run}) {
        print "${YELLOW}$type $self->{name} already exists. Use -f to force overwrite.${NC}\n";
        return 0;
    }
    
    # Validate
    eval { $self->validate(); };
    if ($@) {
        print "${RED}Validation failed: $@${NC}\n";
        return 0;
    }
    
    if ($self->{dry_run}) {
        print "  [DRY RUN] Would create: $target_path\n";
        return 1;
    }
    
    # Pre-creation hook
    $self->pre_create();
    
    # Copy and process template
    $self->copy_template_dir();
    
    # Post-creation hook
    $self->post_create();
    
    return 1;
}

1;