package Infrastructure::Factory;
#
# Factory for creating Infrastructure components
#
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use File::Spec;
use File::Basename;

sub create_infrastructure {
    my $class = shift;
    my %args  = @_;

    my $type = $args{type} || die "Infrastructure type is required";
    my $name = $args{name} || die "Infrastructure name is required";

    # Load the appropriate module
    my $module_name = "Infrastructure::" . ucfirst( lc($type) );
    my $module_file = $module_name;
    $module_file =~ s/::/\//g;
    $module_file .= '.pm';

    eval { require $module_file; };

    if ($@) {
        die "Failed to load infrastructure module $module_name: $@";
    }

    # Create instance
    my $instance = $module_name->new(
        name => $name,
        %args
    );

    return $instance;
}

sub list_infrastructure_types {
    my $lib_dir = shift || 'lib';

    my $infra_dir = "$lib_dir/Infrastructure";
    return () unless -d $infra_dir;

    my @types;
    opendir( my $dh, $infra_dir ) or return ();

    while ( my $file = readdir($dh) ) {
        next if $file =~ /^\./ || $file eq 'Base.pm' || $file eq 'Factory.pm';
        if ( $file =~ /^(\w+)\.pm$/ ) {
            push @types, lc($1);
        }
    }

    closedir($dh);
    return @types;
}

# Get available infrastructure types
sub get_available_types {
    my $class = shift;
    return $class->list_infrastructure_types(@_);
}

1;
