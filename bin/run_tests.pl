#!/usr/bin/perl
#
# Test Runner Script
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use FindBin;
use File::Find;
use File::Spec;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Term::ANSIColor qw(:constants);
use Time::HiRes qw(time);

# Color constants
my $GREEN = GREEN;
my $RED = RED;
my $YELLOW = YELLOW;
my $BLUE = BLUE;
my $CYAN = CYAN;
my $NC = RESET;

# Test configuration - paths relative to project root
my $project_root = dirname($FindBin::Bin);
my $test_dir = "$project_root/t";
my $lib_dir = "$project_root/lib";

# Add lib to @INC
unshift @INC, $lib_dir;

# Statistics
my %stats = (
    total_files => 0,
    passed_files => 0,
    failed_files => 0,
    skipped_files => 0,
    total_tests => 0,
    passed_tests => 0,
    failed_tests => 0,
    start_time => time(),
);

print "${GREEN}===============================================${NC}\n";
print "${GREEN}Perl Infrastructure Test Suite${NC}\n";
print "${GREEN}===============================================${NC}\n";
print "\n";

# Check if test directory exists
unless (-d $test_dir) {
    print "${RED}Error: Test directory '$test_dir' not found${NC}\n";
    exit 1;
}

# Check if lib directory exists  
unless (-d $lib_dir) {
    print "${RED}Error: Library directory '$lib_dir' not found${NC}\n";
    exit 1;
}

print "${BLUE}Test Configuration:${NC}\n";
print "  Test Directory: $test_dir\n";
print "  Library Directory: $lib_dir\n";
print "  Perl Version: $]\n";
print "\n";

# Find all test files
my @test_files;
find(sub {
    return unless -f $_;
    return unless /\.t$/;
    push @test_files, $File::Find::name;
}, $test_dir);

@test_files = sort @test_files;

print "${BLUE}Found " . scalar(@test_files) . " test files:${NC}\n";
foreach my $file (@test_files) {
    my $rel_path = File::Spec->abs2rel($file, $FindBin::Bin);
    print "  - $rel_path\n";
}
print "\n";

if (!@test_files) {
    print "${YELLOW}No test files found${NC}\n";
    exit 0;
}

print "${GREEN}Running Tests:${NC}\n";
print "=" x 50 . "\n";

# Run each test file
foreach my $test_file (@test_files) {
    $stats{total_files}++;
    
    my $rel_path = File::Spec->abs2rel($test_file, $FindBin::Bin);
    print "\n${CYAN}Running: $rel_path${NC}\n";
    
    my $start_time = time();
    
    # Change to the test file's directory to ensure proper paths
    my $orig_dir = Cwd::getcwd();
    my $test_dir_path = File::Spec->rel2abs(dirname($test_file));
    chdir $test_dir_path;
    
    # Run the test
    my $cmd = "perl -I\"$lib_dir\" \"$test_file\" 2>&1";
    my $output = `$cmd`;
    my $exit_code = $? >> 8;
    
    # Change back to original directory
    chdir $orig_dir;
    
    my $duration = sprintf("%.2f", time() - $start_time);
    
    if ($exit_code == 0) {
        print "${GREEN}✓ PASSED${NC} (${duration}s)\n";
        $stats{passed_files}++;
        
        # Parse test results from output
        if ($output =~ /(\d+)\/(\d+)/) {
            $stats{passed_tests} += $1;
            $stats{total_tests} += $2;
        } elsif ($output =~ /All tests successful/) {
            # Extract number if available
            if ($output =~ /(\d+)\s+tests?/) {
                $stats{total_tests} += $1;
                $stats{passed_tests} += $1;
            }
        }
        
        # Show brief output for verbose mode
        if ($ENV{VERBOSE}) {
            print $output;
        }
    } else {
        print "${RED}✗ FAILED${NC} (${duration}s)\n";
        $stats{failed_files}++;
        
        # Show error output
        print "${RED}Error Output:${NC}\n";
        print $output;
        print "\n";
    }
}

print "\n";
print "=" x 50 . "\n";
print "${BLUE}Test Summary:${NC}\n";
print "=" x 50 . "\n";

my $total_duration = sprintf("%.2f", time() - $stats{start_time});

# File statistics
print "${CYAN}Files:${NC}\n";
print "  Total:  $stats{total_files}\n";
if ($stats{passed_files} > 0) {
    print "  ${GREEN}Passed: $stats{passed_files}${NC}\n";
}
if ($stats{failed_files} > 0) {
    print "  ${RED}Failed: $stats{failed_files}${NC}\n";  
}
if ($stats{skipped_files} > 0) {
    print "  ${YELLOW}Skipped: $stats{skipped_files}${NC}\n";
}

# Test statistics
if ($stats{total_tests} > 0) {
    print "\n${CYAN}Tests:${NC}\n";
    print "  Total:  $stats{total_tests}\n";
    if ($stats{passed_tests} > 0) {
        print "  ${GREEN}Passed: $stats{passed_tests}${NC}\n";
    }
    if ($stats{failed_tests} > 0) {
        print "  ${RED}Failed: $stats{failed_tests}${NC}\n";
    }
}

# Overall result
print "\n${CYAN}Duration:${NC} ${total_duration}s\n";

print "\n";
if ($stats{failed_files} == 0) {
    print "${GREEN}===============================================${NC}\n";
    print "${GREEN}ALL TESTS PASSED!${NC}\n";
    print "${GREEN}===============================================${NC}\n";
    exit 0;
} else {
    print "${RED}===============================================${NC}\n";
    print "${RED}SOME TESTS FAILED${NC}\n";
    print "${RED}===============================================${NC}\n";
    exit 1;
}

__END__

=head1 NAME

run_tests.pl - Comprehensive test runner for Perl infrastructure management system

=head1 SYNOPSIS

    ./run_tests.pl [options]

    # Run all tests
    ./run_tests.pl
    
    # Run with verbose output
    VERBOSE=1 ./run_tests.pl
    
    # Run specific test category
    perl run_tests.pl --category lib
    perl run_tests.pl --category integration

=head1 DESCRIPTION

This script runs all Perl test files in the t/ directory and provides comprehensive
reporting of test results. It includes:

- Automatic discovery of .t test files
- Proper library path setup
- Colored output with pass/fail indicators
- Detailed statistics and timing
- Error reporting with output capture
- Support for both unit and integration tests

=head1 TEST STRUCTURE

The test suite is organized as follows:

    t/
    ├── lib/                    # Unit tests for library modules
    │   ├── Infrastructure-*.t  # Infrastructure module tests
    │   ├── Resource-*.t        # Resource module tests
    │   └── API-*.t            # API module tests
    └── integration/           # Integration tests
        ├── manage-*.t         # manage.pl integration tests
        └── deploy-*.t         # Deployment tests

=head1 ENVIRONMENT VARIABLES

=over 4

=item VERBOSE

Set to 1 to show detailed test output even for passing tests.

=back

=head1 EXIT CODES

=over 4

=item 0

All tests passed successfully

=item 1

One or more tests failed

=back

=head1 AUTHOR

Infrastructure Management System Test Suite

=cut
