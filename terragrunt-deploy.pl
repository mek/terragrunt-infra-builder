#!/usr/bin/env perl
#
# Terragrunt Deployment Orchestration Script
# 
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use lib 'lib';
use File::Find;
use File::Basename;
use File::Spec;
use Getopt::Long;
use Data::Dumper;
use Cwd 'abs_path';
use Deploy::Module;
use Time::HiRes qw(time);
use POSIX qw(strftime);
use JSON;
use API::Schema;

# Color codes for output
my $GREEN = "\033[0;32m";
my $YELLOW = "\033[0;33m";
my $RED = "\033[0;31m";
my $BLUE = "\033[0;34m";
my $CYAN = "\033[0;36m";
my $MAGENTA = "\033[0;35m";
my $BOLD = "\033[1m";
my $NC = "\033[0m"; # No Color

# Global variables
my %modules;
my @deployment_order;
my $root_dir = abs_path('.');
my %execution_times;
my $start_time = time();
my @modules_with_outputs;

# Command line options
my $directory_filter = '';
my $tag_filter = '';
my $dry_run = 0;
my $list_only = 0;
my $parallel = 0;
my $destroy = 0;
my $plan_only = 0;
my $init_only = 0;
my $verbose = 0;
my $show_docs = 0;
my $validate_only = 0;
my $force = 0;
my $output_format = 'text'; # text, json, yaml
my $show_outputs = 0;
my $output_module = '';

# Support positional argument as directory alias
if (@ARGV && $ARGV[0] !~ /^-/) {
    $directory_filter = shift @ARGV;
}

GetOptions(
    'dir|d=s'     => \$directory_filter,
    'tag|t=s'     => \$tag_filter,
    'dry-run'     => \$dry_run,
    'list|l'      => \$list_only,
    'parallel|p'  => \$parallel,
    'destroy'     => \$destroy,
    'plan'        => \$plan_only,
    'init'        => \$init_only,
    'verbose|v'   => \$verbose,
    'docs'        => \$show_docs,
    'validate'    => \$validate_only,
    'force|f'     => \$force,
    'format=s'    => \$output_format,
    'output|o=s'  => \$output_module,
    'help|h'      => sub { print_help(); exit 0; }
) or die "Error in command line arguments\n";

# Main execution
sub main {
    print "${BOLD}${GREEN}Terragrunt Intelligent Deployment System${NC}\n";
    print "=" x 60 . "\n\n";
    
    # Discover modules
    discover_modules();
    
    # Load module configurations
    load_module_configs();
    
    # Build dependency graph
    build_dependency_graph();
    
    # Calculate deployment order
    calculate_deployment_order();
    
    # Apply filters
    apply_filters();
    
    # Validate if requested
    if ($validate_only) {
        validate_modules();
        exit 0;
    }
    
    # Show documentation if requested
    if ($show_docs) {
        show_documentation();
        exit 0;
    }
    
    # List modules if requested
    if ($list_only) {
        list_modules();
        exit 0;
    }
    
    # Show outputs if requested
    if ($output_module) {
        show_module_outputs($output_module);
        exit 0;
    }
    
    # Execute deployment
    execute_deployment();
    
    # Show summary
    show_summary();
}

sub print_help {
    print <<'HELP';
Terragrunt Intelligent Deployment System

Usage: terragrunt-deploy.pl [OPTIONS]

Usage: terragrunt-deploy.pl [directory] [OPTIONS]
       terragrunt-deploy.pl [OPTIONS]

Options:
    -d, --dir <path>     Deploy only modules in specified directory
    -t, --tag <tag>      Deploy only modules with specified tag
    --dry-run            Show what would be deployed without executing
    -l, --list           List all modules and their metadata
    -p, --parallel       Deploy independent modules in parallel
    --destroy            Run terragrunt destroy instead of apply
    --plan               Run terragrunt plan only
    --init               Run terragrunt init only
    -v, --verbose        Verbose output
    --docs               Show module documentation
    --validate           Validate module configurations only
    -f, --force          Force deployment even if validations fail
    --format <fmt>       Output format: text, json, yaml
    -o, --output <path>  Show outputs for a specific module
    -h, --help           Show this help message

Module Configuration (deploy.pl):
    Each deployable directory can contain a deploy.pl file that returns
    a Deploy::Module object with the following properties:
    
    - name:          Module name
    - description:   Module description
    - dependencies:  Array of module paths this depends on
    - tags:          Hash of tags for filtering
    - priority:      Deployment priority (0-100)
    - timeout:       Deployment timeout in seconds
    - pre_deploy:    Code ref to run before deployment
    - post_deploy:   Code ref to run after deployment
    - validate:      Code ref to validate before deployment
    - skip_if:       Code ref to determine if module should be skipped
    - retry:         Number of retry attempts
    - parallel_safe: Can be deployed in parallel
    - critical:      Stop all deployment if this fails
    - docs:          Extended documentation
    - owner:         Module owner
    - team:          Responsible team

Examples:
    # Deploy all modules
    ./terragrunt-deploy.pl
    
    # Deploy only production modules (using positional argument)
    ./terragrunt-deploy.pl envs/prod/h2g2/us-west-2
    
    # Deploy only production modules (using option)
    ./terragrunt-deploy.pl -d envs/prod
    
    # Initialize modules
    ./terragrunt-deploy.pl envs/prod/h2g2/_global --init
    
    # Deploy with plan only
    ./terragrunt-deploy.pl envs/prod/h2g2/us-west-2 --plan
    
    # Deploy only modules tagged as 'infrastructure'
    ./terragrunt-deploy.pl -t type=infrastructure
    
    # Validate all module configurations
    ./terragrunt-deploy.pl --validate
    
    # Show module documentation
    ./terragrunt-deploy.pl --docs
    
    # Show outputs for a specific module
    ./terragrunt-deploy.pl -o envs/prod/h2g2/us-west-2/z2wa/eks
    ./terragrunt-deploy.pl --output envs/gdev/h2g2/eu-west-1/eks/z1a

Output Files:
    After successful apply operations, the script automatically creates output.json
    files in each module directory containing:
    - Module metadata (name, path, description)
    - Deployment timestamp and operation details
    - Terragrunt outputs in JSON format
    - These files are used by API servers to provide infrastructure status
    
    Use the -o/--output option to view these outputs from the command line.

HELP
}

sub discover_modules {
    print "${CYAN}Discovering Terragrunt modules...${NC}\n" if $verbose;
    
    my @find_cmd = ('find', '.', '-name', 'terragrunt.hcl', '-not', '-path', '*/.terragrunt-cache/*');
    open(my $fh, '-|', @find_cmd) or die "Cannot run find: $!";
    
    while (my $file = <$fh>) {
        chomp $file;
        
        # Skip root terragrunt.hcl
        next if $file eq './terragrunt.hcl';
        
        # Extract module path
        my $module_path = $file;
        $module_path =~ s/\/terragrunt\.hcl$//;
        $module_path =~ s/^\.\///;
        
        $modules{$module_path} = {
            path => $module_path,
            has_config => -f "$module_path/deploy.pl",
            module => undef,
            dependencies => [],
            dependents => [],
            deployed => 0,
            skipped => 0,
            failed => 0,
        };
        
        print "  Found: $module_path" if $verbose;
        print " [has deploy.pl]" if $verbose && $modules{$module_path}{has_config};
        print "\n" if $verbose;
    }
    
    close $fh;
    
    my $count = scalar keys %modules;
    print "${GREEN}Discovered $count Terragrunt modules${NC}\n\n";
}

sub load_module_configs {
    print "${CYAN}Loading module configurations...${NC}\n" if $verbose;
    
    my $loaded = 0;
    
    foreach my $module_path (keys %modules) {
        my $config_file = "$module_path/deploy.pl";
        
        if (-f $config_file) {
            print "  Loading: $config_file\n" if $verbose;
            
            # Load the module configuration
            my $module_obj = eval {
                local $@;
                my $result = do "./$config_file";
                die "Error loading $config_file: $@" if $@;
                die "$config_file didn't return a Deploy::Module object" 
                    unless ref($result) && $result->isa('Deploy::Module');
                $result;
            };
            
            if ($@) {
                warn "${YELLOW}Warning: Failed to load $config_file: $@${NC}\n";
                # Create a default module
                $module_obj = Deploy::Module->new(
                    name => basename($module_path),
                    description => "Auto-generated module for $module_path",
                );
            }
            
            $modules{$module_path}{module} = $module_obj;
            $loaded++;
        } else {
            # Create a default module for those without deploy.pl
            $modules{$module_path}{module} = Deploy::Module->new(
                name => basename($module_path),
                description => "Auto-discovered module at $module_path",
                priority => 50,
            );
        }
    }
    
    print "${GREEN}Loaded $loaded custom module configurations${NC}\n\n";
}

sub build_dependency_graph {
    print "${CYAN}Building dependency graph...${NC}\n" if $verbose;
    
    foreach my $module_path (keys %modules) {
        my $module = $modules{$module_path}{module};
        next unless $module;
        
        # Process dependencies from module configuration
        if ($module->dependencies && @{$module->dependencies}) {
            foreach my $dep (@{$module->dependencies}) {
                # Handle both absolute and relative dependency paths
                my $dep_path = $dep;
                
                # If it's a relative path, resolve it
                if ($dep !~ /^\//) {
                    # Check if it's a module name or path
                    if (exists $modules{$dep}) {
                        $dep_path = $dep;
                    } else {
                        # Try to find by module name
                        my @matches = grep { 
                            $modules{$_}{module} && 
                            $modules{$_}{module}->name eq $dep 
                        } keys %modules;
                        
                        if (@matches == 1) {
                            $dep_path = $matches[0];
                        } elsif (@matches > 1) {
                            warn "${YELLOW}Warning: Multiple modules named '$dep', using path instead${NC}\n";
                            next;
                        } else {
                            warn "${YELLOW}Warning: Dependency '$dep' not found for $module_path${NC}\n";
                            next;
                        }
                    }
                }
                
                if (exists $modules{$dep_path}) {
                    push @{$modules{$module_path}{dependencies}}, $dep_path;
                    push @{$modules{$dep_path}{dependents}}, $module_path;
                    print "  $module_path -> $dep_path\n" if $verbose;
                }
            }
        }
        
        # Also parse terragrunt.hcl for implicit dependencies
        parse_terragrunt_dependencies($module_path);
    }
}

sub parse_terragrunt_dependencies {
    my $module_path = shift;
    my $terragrunt_file = "$module_path/terragrunt.hcl";
    
    return unless -f $terragrunt_file;
    
    open my $fh, '<', $terragrunt_file or return;
    my $content = do { local $/; <$fh> };
    close $fh;
    
    # Parse dependency blocks
    while ($content =~ /dependency\s+"([^"]+)"\s*{[^}]*path\s*=\s*"([^"]+)"/gs) {
        my ($dep_name, $dep_path) = ($1, $2);
        
        # Resolve relative paths
        if ($dep_path =~ /^\.\./) {
            my $abs_dep_path = File::Spec->rel2abs($dep_path, $module_path);
            $abs_dep_path =~ s/^$root_dir\///;
            
            if (exists $modules{$abs_dep_path}) {
                # Check if dependency already exists
                unless (grep { $_ eq $abs_dep_path } @{$modules{$module_path}{dependencies}}) {
                    push @{$modules{$module_path}{dependencies}}, $abs_dep_path;
                    push @{$modules{$abs_dep_path}{dependents}}, $module_path;
                    print "  $module_path -> $abs_dep_path (from terragrunt.hcl)\n" if $verbose;
                }
            }
        }
    }
}

sub calculate_deployment_order {
    print "${CYAN}Calculating deployment order...${NC}\n" if $verbose;
    
    my %in_degree;
    my @queue;
    
    # Calculate in-degree for each module
    foreach my $module (keys %modules) {
        $in_degree{$module} = scalar @{$modules{$module}{dependencies}};
        
        # Add modules with no dependencies to queue
        if ($in_degree{$module} == 0) {
            push @queue, $module;
        }
    }
    
    # Sort queue by priority
    @queue = sort {
        ($modules{$b}{module}->priority || 50) <=> 
        ($modules{$a}{module}->priority || 50)
    } @queue;
    
    # Topological sort with priority consideration
    while (@queue) {
        my $module = shift @queue;
        push @deployment_order, $module;
        
        foreach my $dependent (@{$modules{$module}{dependents}}) {
            $in_degree{$dependent}--;
            if ($in_degree{$dependent} == 0) {
                push @queue, $dependent;
                
                # Re-sort queue by priority
                @queue = sort {
                    ($modules{$b}{module}->priority || 50) <=> 
                    ($modules{$a}{module}->priority || 50)
                } @queue;
            }
        }
    }
    
    # Check for circular dependencies
    if (scalar @deployment_order != scalar keys %modules) {
        my @stuck = grep { !grep { $_ eq $modules{$_} } @deployment_order } keys %modules;
        die "${RED}Error: Circular dependencies detected involving: " . join(", ", @stuck) . "${NC}\n";
    }
    
    # Reverse for destroy operations
    @deployment_order = reverse @deployment_order if $destroy;
}

sub apply_filters {
    my @filtered_order = @deployment_order;
    
    # Directory filter (works as alias for directory path)
    if ($directory_filter) {
        # Remove trailing slash if present
        $directory_filter =~ s/\/$//;
        
        @filtered_order = grep { $_ =~ /^$directory_filter/ } @filtered_order;
        print "${YELLOW}Filtered to " . scalar(@filtered_order) . " modules in $directory_filter${NC}\n";
    }
    
    # Tag filter
    if ($tag_filter) {
        my ($tag_key, $tag_value) = split /=/, $tag_filter, 2;
        @filtered_order = grep {
            my $module = $modules{$_}{module};
            $module && $module->tags && 
            exists $module->tags->{$tag_key} &&
            (!defined $tag_value || $module->tags->{$tag_key} eq $tag_value)
        } @filtered_order;
        print "${YELLOW}Filtered to " . scalar(@filtered_order) . " modules with tag $tag_filter${NC}\n";
    }
    
    @deployment_order = @filtered_order;
}

sub validate_modules {
    print "${CYAN}Validating modules...${NC}\n";
    print "=" x 60 . "\n";
    
    my $valid = 0;
    my $invalid = 0;
    
    foreach my $module_path (@deployment_order) {
        my $module = $modules{$module_path}{module};
        next unless $module;
        
        print "Validating: $module_path\n";
        
        my $context = {
            path => $module_path,
            root => $root_dir,
            dry_run => $dry_run,
        };
        
        if ($module->run_validate($context)) {
            print "  ${GREEN}✓ Valid${NC}\n";
            $valid++;
        } else {
            print "  ${RED}✗ Invalid${NC}\n";
            $invalid++;
        }
    }
    
    print "\n${GREEN}Valid: $valid${NC}, ${RED}Invalid: $invalid${NC}\n";
}

sub show_documentation {
    print "${CYAN}Module Documentation${NC}\n";
    print "=" x 60 . "\n\n";
    
    foreach my $module_path (@deployment_order) {
        my $module = $modules{$module_path}{module};
        next unless $module;
        
        print "${BOLD}$module_path${NC}\n";
        print "-" x 40 . "\n";
        
        print $module->to_string();
        
        if ($module->docs) {
            print "\n${CYAN}Documentation:${NC}\n";
            print $module->docs . "\n";
        }
        
        print "\n";
    }
}

sub list_modules {
    if ($output_format eq 'json') {
        require JSON;
        my @module_list = map {
            {
                path => $_,
                name => $modules{$_}{module}->name,
                description => $modules{$_}{module}->description,
                dependencies => $modules{$_}{dependencies},
                priority => $modules{$_}{module}->priority,
                tags => $modules{$_}{module}->tags,
            }
        } @deployment_order;
        
        print JSON->new->pretty->encode(\@module_list);
    } else {
        print "${GREEN}Deployment Order:${NC}\n";
        print "=" x 60 . "\n";
        
        my $index = 1;
        foreach my $module_path (@deployment_order) {
            my $module = $modules{$module_path}{module};
            
            print sprintf("%3d. ${BOLD}%-40s${NC}", $index++, $module_path);
            
            # Show priority if not default
            if ($module->priority != 50) {
                print " ${MAGENTA}[P:$module->{priority}]${NC}";
            }
            
            # Show dependencies
            if (@{$modules{$module_path}{dependencies}}) {
                print " ${YELLOW}[→ " . 
                      join(', ', map { basename($_) } @{$modules{$module_path}{dependencies}}) . 
                      "]${NC}";
            }
            
            # Show tags
            if ($module->tags && %{$module->tags}) {
                print " ${CYAN}[";
                print join(', ', map { "$_=$module->{tags}{$_}" } keys %{$module->tags});
                print "]${NC}";
            }
            
            print "\n";
            
            # Show description if verbose
            if ($verbose && $module->description) {
                print "     $module->{description}\n";
            }
        }
    }
}

sub execute_deployment {
    if ($dry_run) {
        print "${YELLOW}DRY RUN MODE - No actual deployment will be performed${NC}\n\n";
    }
    
    my $operation = $destroy ? 'destroy' : 
                   ($plan_only ? 'plan' : 
                   ($init_only ? 'init' : 'apply'));
    print "${GREEN}Starting Terragrunt $operation...${NC}\n";
    print "=" x 60 . "\n\n";
    
    my $total = scalar @deployment_order;
    my $current = 0;
    my $succeeded = 0;
    my $failed = 0;
    my $skipped = 0;
    
    foreach my $module_path (@deployment_order) {
        $current++;
        my $module = $modules{$module_path}{module};
        
        # Check if should skip
        my $context = {
            path => $module_path,
            root => $root_dir,
            dry_run => $dry_run,
            operation => $operation,
        };
        
        if ($module->should_skip($context)) {
            print "${BLUE}[$current/$total] ${YELLOW}Skipping: $module_path${NC}\n";
            print "  Reason: Module skip condition met\n" if $verbose;
            $modules{$module_path}{skipped} = 1;
            $skipped++;
            next;
        }
        
        print "${BLUE}[$current/$total] ${GREEN}Deploying: $module_path${NC}\n";
        print "  ${CYAN}" . $module->description . "${NC}\n" if $module->description && $verbose;
        
        # Pre-deploy hook
        if (!$dry_run && !$module->run_pre_deploy($context)) {
            print "  ${RED}Pre-deploy hook failed${NC}\n";
            $failed++;
            $modules{$module_path}{failed} = 1;
            
            if ($module->critical) {
                die "${RED}Critical module failed. Stopping deployment.${NC}\n";
            }
            next;
        }
        
        # Execute deployment
        if (!$dry_run) {
            my $attempts = 0;
            my $max_attempts = $module->retry + 1;
            my $success = 0;
            
            while ($attempts < $max_attempts && !$success) {
                $attempts++;
                
                if ($attempts > 1) {
                    print "  ${YELLOW}Retry attempt $attempts/$max_attempts${NC}\n";
                }
                
                print "  ${CYAN}Changing to $module_path to run terragrunt $operation${NC}\n";
                
                my $terragrunt_cmd = "terragrunt $operation";
                
                unless ($plan_only || $init_only) {
                    $terragrunt_cmd .= " --non-interactive";
                    $terragrunt_cmd .= " -auto-approve" unless $destroy;
                }
                
                if ($destroy) {
                    $terragrunt_cmd .= " -auto-approve";
                }
                
                if ($init_only) {
                    $terragrunt_cmd .= " --non-interactive";
                }
                
                # Add timeout to terragrunt command only
                $terragrunt_cmd = "timeout $module->{timeout} $terragrunt_cmd" if $module->timeout;
                
                # Combine cd and terragrunt command
                my $cmd = "cd '$module_path' && $terragrunt_cmd";
                
                print "  ${CYAN}Full command: $cmd${NC}\n" if $verbose;
                
                my $start = time();
                my $result = system($cmd);
                $execution_times{$module_path} = time() - $start;
                
                if ($result == 0) {
                    $success = 1;
                    print "  ${GREEN}✓ Successfully completed${NC} (%.1fs)\n", $execution_times{$module_path};
                    $modules{$module_path}{deployed} = 1;
                    $succeeded++;
                    
                    # Post-deploy hook
                    if (!$module->run_post_deploy($context)) {
                        warn "  ${YELLOW}Warning: Post-deploy hook failed${NC}\n";
                    }
                    
                    # Capture module outputs after successful deployment
                    capture_module_outputs($module_path, $operation);
                } elsif ($attempts < $max_attempts) {
                    print "  ${YELLOW}Failed, will retry...${NC}\n";
                    sleep 5; # Wait before retry
                }
            }
            
            if (!$success) {
                print "  ${RED}✗ Failed after $attempts attempts${NC}\n";
                $modules{$module_path}{failed} = 1;
                $failed++;
                
                if ($module->critical && !$force) {
                    die "${RED}Critical module failed. Stopping deployment.${NC}\n";
                }
            }
        } else {
            print "  Would run: terragrunt $operation\n";
        }
        
        print "\n";
    }
    
    # Store final counts for summary
    $modules{_summary} = {
        total => $total,
        succeeded => $succeeded,
        failed => $failed,
        skipped => $skipped,
    };
}

sub show_module_outputs {
    my $module_path = shift;
    
    print "${CYAN}Module Outputs: $module_path${NC}\n";
    print "=" x 60 . "\n\n";
    
    # Check if output.json exists
    my $output_file = "$module_path/output.json";
    if (!-f $output_file) {
        print "${RED}Error: No output.json found for $module_path${NC}\n";
        print "This module may not have been deployed yet or has no outputs.\n\n";
        
        # Show available modules with outputs
        my @modules_with_files = grep { -f "$_/output.json" } keys %modules;
        if (@modules_with_files) {
            print "${YELLOW}Available modules with outputs:${NC}\n";
            foreach my $path (@modules_with_files) {
                print "  - $path\n";
            }
            print "\nUse: ./terragrunt-deploy.pl -o <module_path> to view outputs\n";
        }
        return;
    }
    
    # Read and display the output.json file
    eval {
        open(my $fh, '<', $output_file) or die "Cannot open $output_file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        
        # Parse JSON
        my $json_data = JSON->new->decode($content);
        
        # Display in a formatted way
        print "${BOLD}Module Information:${NC}\n";
        print "-" x 30 . "\n";
        print "Path: $json_data->{module}{path}\n";
        print "Name: $json_data->{module}{name}\n";
        if ($json_data->{module}{description}) {
            print "Description: $json_data->{module}{description}\n";
        }
        
        print "\n${BOLD}Deployment Details:${NC}\n";
        print "-" x 30 . "\n";
        print "Timestamp: $json_data->{deployment}{timestamp}\n";
        print "Operation: $json_data->{deployment}{operation}\n";
        print "Status: " . ($json_data->{deployment}{success} ? "${GREEN}Success${NC}" : "${RED}Failed${NC}") . "\n";
        
        print "\n${BOLD}Terragrunt Outputs:${NC}\n";
        print "-" x 30 . "\n";
        
        if ($json_data->{outputs} && %{$json_data->{outputs}}) {
            foreach my $output_name (sort keys %{$json_data->{outputs}}) {
                my $output = $json_data->{outputs}{$output_name};
                print "${CYAN}$output_name${NC}:\n";
                print "  Type: $output->{type}\n";
                
                # Handle different value types properly
                if (ref($output->{value}) eq 'ARRAY') {
                    print "  Value: [" . join(", ", @{$output->{value}}) . "]\n";
                } elsif (ref($output->{value}) eq 'HASH') {
                    print "  Value: " . JSON->new->encode($output->{value}) . "\n";
                } else {
                    print "  Value: $output->{value}\n";
                }
                print "\n";
            }
        } else {
            print "${YELLOW}No outputs found${NC}\n";
        }
        
        # Option to show raw JSON
        if ($verbose) {
            print "${BOLD}Raw JSON:${NC}\n";
            print "-" x 30 . "\n";
            print JSON->new->pretty->encode($json_data);
        }
        
    };
    
    if ($@) {
        print "${RED}Error reading output.json: $@${NC}\n";
    }
}

sub capture_module_outputs {
    my $module_path = shift;
    my $operation = shift;
    
    # Only capture outputs after successful apply operations
    return unless $operation eq 'apply';
    
    print "  ${CYAN}Capturing module outputs...${NC}\n";
    
    # Change to module directory and run terragrunt output -json
    my $output_cmd = "cd '$module_path' && terragrunt output -json 2>/dev/null";
    my $outputs = `$output_cmd`;
    
    if ($outputs && $outputs ne '') {
        # Parse the JSON output
        my $json_data;
        eval {
            require JSON;
            $json_data = JSON->new->decode($outputs);
        };
        
        if ($@ || !$json_data) {
            warn "  ${YELLOW}Warning: Failed to parse terragrunt outputs for $module_path${NC}\n";
            print "  ${YELLOW}Warning: Failed to parse terragrunt outputs for $module_path${NC}\n";
            return;
        }
        
        # Get module information
        my $module = $modules{$module_path}{module};
        my $module_name = $module ? $module->name : basename($module_path);
        
        # Extract hierarchy information from path
        my @path_parts = split('/', $module_path);
        my ($env_name, $region_name, $zone_name, $project_name);
        
        if (@path_parts >= 2) {
            $env_name = $path_parts[1];  # envs/dev/...
        }
        if (@path_parts >= 3) {
            # Could be region or project depending on structure
            if (@path_parts >= 4 && $path_parts[3] =~ /^(us-|eu-|ap-)/) {
                $project_name = $path_parts[2];
                $region_name = $path_parts[3];
                $zone_name = $path_parts[4] if @path_parts >= 5;
            } else {
                $region_name = $path_parts[2];
                $zone_name = $path_parts[3] if @path_parts >= 4;
            }
        }
        
        # Create standardized API document
        my $enhanced_output = API::Schema->create_resource_document(
            path => $module_path,
            name => $module_name,
            type => extract_resource_type_from_path($module_path),
            category => get_resource_category($module_path),
            env_name => $env_name,
            region_name => $region_name,
            zone_name => $zone_name,
            project_name => $project_name,
            operation => $operation,
            success => 1,
            execution_time => $execution_times{$module_path} || 0,
            raw_outputs => $json_data,
        );
        
        # Write to output.json file  
        my $output_file = "$module_path/output.json";
        eval {
            open(my $fh, '>', $output_file) or die "Cannot open $output_file for writing: $!";
            print $fh API::Schema->to_json($enhanced_output);
            close $fh;
            print "  ${GREEN}✓ Outputs captured to $output_file${NC}\n";
            
            # Track successful output capture
            push @modules_with_outputs, $module_path;
        };
        
        if ($@) {
            warn "  ${YELLOW}Warning: Failed to write output.json for $module_path: $output_file: $@${NC}\n";
        }
    } else {
        print "  ${YELLOW}No outputs found for $module_path${NC}\n";
    }
}

sub show_summary {
    print "=" x 60 . "\n";
    print "${BOLD}Deployment Summary${NC}\n";
    print "=" x 60 . "\n";
    
    if (!$dry_run && $modules{_summary}) {
        my $s = $modules{_summary};
        
        print "${GREEN}Succeeded: $s->{succeeded}${NC}\n" if $s->{succeeded};
        print "${RED}Failed: $s->{failed}${NC}\n" if $s->{failed};
        print "${YELLOW}Skipped: $s->{skipped}${NC}\n" if $s->{skipped};
        print "Total: $s->{total}\n";
        
        # Show execution times
        if (%execution_times) {
            my $total_time = time() - $start_time;
            print "\n${CYAN}Execution Times:${NC}\n";
            
            my @sorted = sort { $execution_times{$b} <=> $execution_times{$a} } keys %execution_times;
            my $shown = 0;
            
            foreach my $path (@sorted[0..4]) {
                last unless defined $path;
                printf "  %-40s %.1fs\n", basename($path), $execution_times{$path};
                $shown++;
            }
            
            printf "\n${BOLD}Total execution time: %.1fs${NC}\n", $total_time;
        }
        
        # Show failed modules
        if ($modules{_summary}{failed} > 0) {
            print "\n${RED}Failed Modules:${NC}\n";
            foreach my $path (keys %modules) {
                next if $path eq '_summary';
                if ($modules{$path}{failed}) {
                    print "  - $path\n";
                }
            }
        }
        
        # Show modules with outputs captured
        if (@modules_with_outputs) {
            print "\n${CYAN}Outputs Captured:${NC}\n";
            foreach my $path (@modules_with_outputs) {
                print "  - $path/output.json\n";
            }
        }
    } else {
        print "${YELLOW}Dry run complete${NC}\n";
        print "Would deploy " . scalar(@deployment_order) . " modules\n";
        print "${CYAN}Note: output.json files would be created after successful apply operations${NC}\n";
    }
    
    print "\n" . strftime("%Y-%m-%d %H:%M:%S", localtime) . "\n";
}

# Helper functions for API schema integration

sub extract_resource_type_from_path {
    my $path = shift;
    
    # Extract the last directory name as resource type
    my $resource_name = basename($path);
    
    # Try to map to known resource types
    my %type_mapping = (
        'eks'         => 'eks',
        'vpc'         => 'vpc',
        'rds'         => 'rds', 
        'alb'         => 'alb',
        'nlb'         => 'nlb',
        'lambda'      => 'lambda',
        's3'          => 's3',
        'iam'         => 'iam',
        'security-group' => 'security-group',
        'sg'          => 'security-group',
    );
    
    # Check for exact match
    return $type_mapping{$resource_name} if exists $type_mapping{$resource_name};
    
    # Check for partial match
    foreach my $key (keys %type_mapping) {
        if ($resource_name =~ /\Q$key\E/i) {
            return $type_mapping{$key};
        }
    }
    
    return $resource_name;  # Return as-is if no mapping found
}

sub get_resource_category {
    my $path = shift;
    my $resource_type = extract_resource_type_from_path($path);
    
    my %categories = (
        compute     => ['eks', 'ecs', 'ec2', 'lambda', 'batch', 'lightsail', 'fargate'],
        networking  => ['vpc', 'security-group', 'alb', 'nlb', 'internet-gateway', 'nat-gateway', 'route53', 'cloudfront', 'api-gateway'],
        storage     => ['s3', 'efs', 'fsx', 'ebs', 'backup'],
        database    => ['rds', 'aurora', 'dynamodb', 'elasticache', 'documentdb', 'neptune'],
        security    => ['iam', 'kms', 'secrets-manager', 'acm', 'waf', 'shield', 'guardduty'],
        monitoring  => ['cloudwatch', 'cloudtrail', 'sns', 'sqs', 'eventbridge', 'ssm'],
        analytics   => ['opensearch', 'sagemaker', 'emr', 'glue', 'athena', 'kinesis'],
        devops      => ['codebuild', 'codepipeline', 'codecommit', 'codedeploy'],
    );
    
    foreach my $category (keys %categories) {
        if (grep { $_ eq $resource_type } @{$categories{$category}}) {
            return $category;
        }
    }
    
    return 'other';
}

# Run main
main();
