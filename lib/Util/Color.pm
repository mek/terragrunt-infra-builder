package Util::Color;
#
# Color utility module for consistent terminal output
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use Exporter 'import';

# Export color constants and utility functions
our @EXPORT = qw(
    $GREEN $YELLOW $RED $BLUE $CYAN $MAGENTA $BOLD $NC
    colored colorize
);

# ANSI color codes
our $GREEN   = "\033[0;32m";
our $YELLOW  = "\033[0;33m";  
our $RED     = "\033[0;31m";
our $BLUE    = "\033[0;34m";
our $CYAN    = "\033[0;36m";
our $MAGENTA = "\033[0;35m";
our $BOLD    = "\033[1m";
our $NC      = "\033[0m";     # No Color

# Utility function to colorize text
# Usage: colored('text', 'red') or colored('text', $RED)
sub colored {
    my ($text, $color) = @_;
    
    # Handle color name strings
    if (defined $color && $color !~ /^\033/) {
        my %color_map = (
            'green'   => $GREEN,
            'yellow'  => $YELLOW,
            'red'     => $RED,
            'blue'    => $BLUE,
            'cyan'    => $CYAN,
            'magenta' => $MAGENTA,
            'bold'    => $BOLD,
        );
        $color = $color_map{lc($color)} || '';
    }
    
    return defined $color ? "$color$text$NC" : $text;
}

# Alias for colored() for consistency
sub colorize {
    return colored(@_);
}

# Check if colors should be disabled (for testing or non-terminal output)
sub should_use_colors {
    # Disable colors if:
    # 1. NO_COLOR environment variable is set
    # 2. Output is not to a terminal
    return 0 if $ENV{NO_COLOR};
    return 0 unless -t STDOUT;
    return 1;
}

# Initialize color support - call this to potentially disable colors
sub init_colors {
    if (!should_use_colors()) {
        # Disable all colors
        $GREEN = $YELLOW = $RED = $BLUE = $CYAN = $MAGENTA = $BOLD = $NC = '';
    }
}

1;

__END__

=head1 NAME

Util::Color - Terminal color utilities

=head1 SYNOPSIS

    use Util::Color;
    
    # Using color constants
    print "${GREEN}Success!${NC}\n";
    print "${RED}Error!${NC}\n";
    
    # Using utility functions  
    print colored('Success!', 'green') . "\n";
    print colored('Error!', $RED) . "\n";
    
    # Initialize colors (call once at startup)
    Util::Color::init_colors();

=head1 DESCRIPTION

This module provides consistent terminal color handling across the terragrunt infrastructure builder.

=head1 EXPORTS

=over 4

=item Color constants: C<$GREEN>, C<$YELLOW>, C<$RED>, C<$BLUE>, C<$CYAN>, C<$MAGENTA>, C<$BOLD>, C<$NC>

=item Functions: C<colored()>, C<colorize()>

=back

=head1 FUNCTIONS

=over 4

=item colored($text, $color)

Returns text wrapped in color codes. Color can be a string name or ANSI code.

=item should_use_colors()

Returns true if colors should be used (respects NO_COLOR env var and terminal detection).

=item init_colors()

Call once at startup to initialize color support. Disables colors if appropriate.

=back

=cut