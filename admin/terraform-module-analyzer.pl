#!/usr/bin/env perl
#
# Terraform Module Analyzer and Input Generator
#
# Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>
# Licensed under the MIT License - see LICENSE file for details

use strict;
use warnings;
use lib 'lib';
use File::Find;
use File::Basename;
use File::Spec;
use File::Path qw(make_path remove_tree);
use Getopt::Long;
use Data::Dumper;
use Cwd 'abs_path';
use JSON;
use POSIX qw(strftime);
use lib '../lib';
use Util::Color;

# URI parsing handled manually

# Global variables
my $workspace_root;
my %modules;
my %unique_modules;
my %module_schemas;
my $work_dir = "/tmp/terraform_module_analysis";
my $verbose  = 0;
my $dry_run  = 0;
my $force    = 0;

# Command line options
GetOptions(
    'verbose|v'  => \$verbose,
    'dry-run'    => \$dry_run,
    'force|f'    => \$force,
    'work-dir=s' => \$work_dir,
    'help|h'     => sub { print_help(); exit 0; }
) or die "Error in command line arguments\n";

# Main execution
sub main {

    # Initialize colors
    Util::Color::init_colors();

    print "${BOLD}${GREEN}Terraform Module Analyzer${NC}\n";
    print "=" x 60 . "\n\n";

    # Find workspace root
    find_workspace_root();

    # Step 1: Extract modules from terragrunt files
    print "${CYAN}Step 1: Extracting modules from terragrunt files...${NC}\n";
    extract_modules_from_terragrunt();

    # Step 2: Analyze unique modules
    print "\n${CYAN}Step 2: Analyzing unique modules...${NC}\n";
    analyze_unique_modules();

    # Step 3: Generate module schemas
    print "\n${CYAN}Step 3: Generating module schemas...${NC}\n";
    generate_module_schemas();

    # Step 4: Generate inputs.json files
    print "\n${CYAN}Step 4: Generating inputs.json files...${NC}\n";
    generate_inputs_files();

    # Step 5: Save analysis results
    print "\n${CYAN}Step 5: Saving analysis results...${NC}\n";
    save_analysis_results();

    print "\n${GREEN}Analysis complete!${NC}\n";
    show_summary();
}

sub print_help {
    print <<'HELP';
Terraform Module Analyzer

Usage: terraform-module-analyzer.pl [OPTIONS]

Options:
    -v, --verbose        Verbose output
    --dry-run           Show what would be done without executing
    -f, --force         Force re-cloning of repositories
    --work-dir <path>   Working directory for git operations (default: /tmp/terraform_module_analysis)
    -h, --help          Show this help message

What this script does:
1. Scans all terragrunt.hcl files recursively
2. Extracts module source URLs and paths
3. Identifies unique modules across the workspace
4. Clones repositories and analyzes variables.tf files
5. Generates JSON schemas for each module
6. Creates inputs.json files for each deployment directory
7. Saves comprehensive analysis results

Examples:
    # Run complete analysis
    ./terraform-module-analyzer.pl
    
    # Run with verbose output
    ./terraform-module-analyzer.pl -v
    
    # Dry run to see what would be done
    ./terraform-module-analyzer.pl --dry-run

HELP
}

sub find_workspace_root {
    my $current_dir = abs_path('.');

    # Look for terragrunt.hcl in current directory or parents
    my $dir = $current_dir;
    while ( $dir ne '/' ) {
        if ( -f "$dir/terragrunt.hcl" ) {
            $workspace_root = $dir;
            last;
        }
        $dir = dirname($dir);
    }

    if ( !$workspace_root ) {
        die
"${RED}Error: Could not find workspace root (no terragrunt.hcl found)${NC}\n";
    }

    print "${GREEN}Workspace root: $workspace_root${NC}\n";
}

sub extract_modules_from_terragrunt {
    print "  Scanning for terragrunt.hcl files...\n";

    my @terragrunt_files;
    find(
        sub {
            if ( $_ eq 'terragrunt.hcl' ) {
                push @terragrunt_files, $File::Find::name;
            }
        },
        $workspace_root
    );

    print "  Found " . scalar(@terragrunt_files) . " terragrunt.hcl files\n";

    my $total_modules = 0;
    foreach my $file (@terragrunt_files) {
        my $file_modules = extract_modules_from_file($file);
        $total_modules += scalar(@$file_modules);

        # Store modules with their file paths
        foreach my $module (@$file_modules) {
            $module->{file_path} = $file;
            push @{ $modules{$file} }, $module;
        }
    }

    print "  Found $total_modules total module references\n";
}

sub extract_modules_from_file {
    my $file_path = shift;
    my @modules;

    open( my $fh, '<', $file_path ) or do {
        warn "  ${YELLOW}Warning: Cannot read $file_path: $!${NC}\n";
        return \@modules;
    };

    my $content = do { local $/; <$fh> };
    close $fh;

    # Find all source lines
    while ( $content =~ /source\s*=\s*"([^"]+)"/g ) {
        my $source      = $1;
        my $module_info = extract_module_info($source);
        push @modules, $module_info;
    }

    return \@modules;
}

sub extract_module_info {
    my $source = shift;

    # Skip invalid sources (terragrunt functions, relative paths, etc.)
    if (   $source =~ /^\$\{.*\}/
        || $source =~ /^\.\.\/|^\.\//
        || $source =~ /^[^\/]+\/[^\/]+$/ )
    {
        return {
            type        => 'skip',
            repo        => $source,
            module_path => '',
            ref         => undef,
            full_source => $source,
            reason      => 'Invalid or unsupported source format'
        };
    }

    if ( $source =~ /^git::(.+)$/ ) {

        # Handle git::https:// format
        my $url_part = $1;
        my ( $url, $ref );

        if ( $url_part =~ /(.+)\?(.+)$/ ) {
            $url = $1;
            my $query = $2;
            if ( $query =~ /ref=([^&]+)/ ) {
                $ref = $1;
            }
        }
        else {
            $url = $url_part;
            $ref = undef;
        }

        my $module_path = '';
        if ( $url =~ /\/\/modules\/(.+)$/ ) {
            $module_path = $1;
            $url =~ s/\/\/modules\/.+$//;
        }

        return {
            type        => 'git_https',
            repo        => $url,
            module_path => $module_path,
            ref         => $ref,
            full_source => $source
        };
    }
    elsif ( $source =~ /^git@(.+)$/ ) {

        # Handle git@github.com: format
        my $ssh_url     = $source;
        my $module_path = '';

        if ( $ssh_url =~ /\/\/(.+)$/ ) {
            $module_path = $1;
            $ssh_url =~ s/\/\/.+$//;
        }

        my $repo = $ssh_url;
        $repo =~ s/git\@github\.com:/https:\/\/github.com\//;

        return {
            type        => 'git_ssh',
            repo        => $repo,
            module_path => $module_path,
            ref         => undef,
            full_source => $source
        };
    }
    else {
        return {
            type        => 'unknown',
            repo        => $source,
            module_path => '',
            ref         => undef,
            full_source => $source
        };
    }
}

sub analyze_unique_modules {
    print "  Identifying unique modules...\n";

    my %seen_sources;
    my $unique_count = 0;

    foreach my $file ( keys %modules ) {
        foreach my $module ( @{ $modules{$file} } ) {
            my $key = get_module_key($module);
            if ( !exists $seen_sources{$key} ) {
                $seen_sources{$key}   = 1;
                $unique_modules{$key} = $module;
                $unique_count++;
            }
        }
    }

    print "  Found $unique_count unique modules\n";

    # Group by type
    my %grouped_modules;
    foreach my $key ( keys %unique_modules ) {
        my $module = $unique_modules{$key};
        my $type   = $module->{type};
        push @{ $grouped_modules{$type} }, $module;
    }

    print "  Module breakdown by type:\n";
    foreach my $type ( keys %grouped_modules ) {
        print "    $type: "
          . scalar( @{ $grouped_modules{$type} } )
          . " modules\n";
        if ( $type eq 'skip' ) {
            foreach my $module ( @{ $grouped_modules{$type} } ) {
                print "      - $module->{repo} ($module->{reason})\n";
            }
        }
    }
}

sub get_module_key {
    my $module      = shift;
    my $repo        = $module->{repo};
    my $module_path = $module->{module_path} || '';
    my $ref         = $module->{ref}         || 'latest';

    # Handle URLs with //modules/ in them
    if ( $repo =~ /\/\/modules\// ) {
        $repo =~ s/\/\/modules\/.+$//;
    }

    return "${repo}_${module_path}_${ref}";
}

sub generate_module_schemas {
    print "  Creating working directory: $work_dir\n";
    make_path($work_dir) unless -d $work_dir;

    my $processed = 0;
    my $skipped   = 0;
    foreach my $key ( keys %unique_modules ) {
        my $module = $unique_modules{$key};

        # Skip modules that can't be processed
        if ( $module->{type} eq 'skip' ) {
            print "  Skipping: $key ($module->{reason})\n";
            $skipped++;
            next;
        }

        print "  Processing: $key\n";

        my $schema = analyze_module($module);
        if ($schema) {
            $module_schemas{$key} = $schema;
            $processed++;
        }
    }

    print "  Successfully processed $processed modules\n";
    print "  Skipped $skipped modules (unsupported format)\n";
}

sub analyze_module {
    my $module      = shift;
    my $repo_url    = $module->{repo};
    my $ref         = $module->{ref};
    my $module_path = $module->{module_path};

    # Clone repository
    my $repo_dir = clone_repository( $repo_url, $ref );
    return undef unless $repo_dir;

    # Find variables.tf file
    my $variables_file = find_variables_file( $repo_dir, $module_path );
    return undef unless $variables_file;

    # Parse variables
    my $variables = parse_variables_tf($variables_file);

    # Generate schema
    my $schema = generate_json_schema( $variables, $repo_url );

    return $schema;
}

sub clone_repository {
    my $repo_url = shift;
    my $ref      = shift;

    # Extract repo name from URL
    my $repo_name = $repo_url;
    $repo_name =~ s/.*\///;
    $repo_name =~ s/\.git$//;

    my $clone_dir = "$work_dir/$repo_name";

    if ( -d $clone_dir && !$force ) {
        print "    Repository $repo_name already exists, skipping clone...\n";
        return $clone_dir;
    }

    print "    Cloning $repo_url...\n";

    if ($dry_run) {
        print "    [DRY RUN] Would clone $repo_url to $clone_dir\n";
        return $clone_dir;
    }

    # Remove existing directory if forcing
    if ( -d $clone_dir && $force ) {
        remove_tree($clone_dir);
    }

    my $clone_cmd = "git clone --depth 1";
    $clone_cmd .= " --branch $ref" if $ref;
    $clone_cmd .= " '$repo_url' '$clone_dir'";

    my $result = system($clone_cmd);
    if ( $result != 0 ) {
        warn "    ${RED}Error cloning $repo_url${NC}\n";
        return undef;
    }

    print "    Successfully cloned $repo_name\n";
    return $clone_dir;
}

sub find_variables_file {
    my $repo_dir    = shift;
    my $module_path = shift;

    my $search_dir = $repo_dir;
    if ($module_path) {
        if ( $module_path =~ /^modules\// ) {
            $search_dir = "$repo_dir/$module_path";
        }
        else {
            $search_dir = "$repo_dir/modules/$module_path";
        }
    }

    my $variables_file = "$search_dir/variables.tf";
    if ( -f $variables_file ) {
        return $variables_file;
    }

    # Also check root if no module_path
    if ( !$module_path ) {
        $variables_file = "$repo_dir/variables.tf";
        if ( -f $variables_file ) {
            return $variables_file;
        }
    }

    return undef;
}

sub parse_variables_tf {
    my $variables_file = shift;
    my @variables;

    open( my $fh, '<', $variables_file ) or do {
        warn "    ${YELLOW}Warning: Cannot read $variables_file: $!${NC}\n";
        return \@variables;
    };

    my $content = do { local $/; <$fh> };
    close $fh;

    # Parse variable blocks
    while ( $content =~ /variable\s+"([^"]+)"\s*\{([^}]+)\}/gs ) {
        my ( $var_name, $var_body ) = ( $1, $2 );

        my $var_info = {
            name        => $var_name,
            description => '',
            type        => 'string',
            default     => undef,
            required    => 1,
            validation  => []
        };

        # Extract description
        if ( $var_body =~ /description\s*=\s*"([^"]*)"/ ) {
            $var_info->{description} = $1;
        }

        # Extract type
        if ( $var_body =~ /type\s*=\s*([^\s\n]+)/ ) {
            $var_info->{type} = $1;
        }

        # Extract default value
        if ( $var_body =~ /default\s*=\s*([^\s\n]+)/ ) {
            $var_info->{default}  = $1;
            $var_info->{required} = 0;
        }

        # Extract validation rules
        while ( $var_body =~ /validation\s*\{([^}]+)\}/gs ) {
            my $validation = $1;
            my $val_info   = {};

            if ( $validation =~ /condition\s*=\s*([^\s\n]+)/ ) {
                $val_info->{condition} = $1;
            }

            if ( $validation =~ /error_message\s*=\s*"([^"]*)"/ ) {
                $val_info->{error_message} = $1;
            }

            if (%$val_info) {
                push @{ $var_info->{validation} }, $val_info;
            }
        }

        push @variables, $var_info;
    }

    return \@variables;
}

sub generate_json_schema {
    my $variables   = shift;
    my $module_name = shift;

    my $schema = {
        '$schema'            => 'http://json-schema.org/draft-07/schema#',
        title                => "Terraform Module: $module_name",
        type                 => 'object',
        properties           => {},
        required             => [],
        additionalProperties => 0
    };

    foreach my $var (@$variables) {
        my $prop_schema = convert_terraform_type_to_json_schema( $var->{type} );

        if ( $var->{description} ) {
            $prop_schema->{description} = $var->{description};
        }

        if ( defined $var->{default} ) {
            $prop_schema->{default} = $var->{default};
        }

        if ( @{ $var->{validation} } ) {
            $prop_schema->{custom_validation} = $var->{validation};
        }

        $schema->{properties}->{ $var->{name} } = $prop_schema;

        if ( $var->{required} ) {
            push @{ $schema->{required} }, $var->{name};
        }
    }

    return $schema;
}

sub convert_terraform_type_to_json_schema {
    my $terraform_type = shift;
    $terraform_type =~ s/^\s+|\s+$//g;

    if ( $terraform_type =~ /^string$/ ) {
        return { type => 'string' };
    }
    elsif ( $terraform_type =~ /^number$/ ) {
        return { type => 'number' };
    }
    elsif ( $terraform_type =~ /^bool$/ ) {
        return { type => 'boolean' };
    }
    elsif ( $terraform_type =~ /^list\((.+)\)$/ ) {
        my $item_type = $1;
        return {
            type  => 'array',
            items => convert_terraform_type_to_json_schema($item_type)
        };
    }
    elsif ( $terraform_type =~ /^map\((.+)\)$/ ) {
        my $item_type = $1;
        return {
            type                 => 'object',
            additionalProperties =>
              convert_terraform_type_to_json_schema($item_type)
        };
    }
    elsif ( $terraform_type =~ /^object\((.+)\)$/ ) {
        return { type => 'object' };
    }
    else {
        return { type => 'string' };
    }
}

sub generate_inputs_files {
    print "  Generating inputs.json files...\n";

    my $generated = 0;
    foreach my $file ( keys %modules ) {
        my $dir    = dirname($file);
        my $inputs = create_inputs_json( $file, $dir );

        if ($inputs) {
            my $inputs_file = "$dir/inputs.json";

            # Check if file already exists and skip unless force is used
            if ( -f $inputs_file && !$force ) {
                print
"    Skipped: $inputs_file (already exists, use --force to overwrite)\n";
                next;
            }

            if ( !$dry_run ) {
                open( my $fh, '>', $inputs_file ) or do {
                    warn
"    ${YELLOW}Warning: Cannot write $inputs_file: $!${NC}\n";
                    next;
                };
                print $fh JSON->new->pretty->encode($inputs);
                close $fh;
            }
            print "    Generated: $inputs_file\n";
            $generated++;
        }
    }

    print "  Generated $generated inputs.json files\n";
}

sub create_inputs_json {
    my $file = shift;
    my $dir  = shift;

    my $inputs = {
        module_info => {
            file_path => $file,
            modules   => []
        },
        variables => {}
    };

    foreach my $module ( @{ $modules{$file} } ) {
        my $key    = get_module_key($module);
        my $schema = $module_schemas{$key};

        if ($schema) {
            push @{ $inputs->{module_info}->{modules} },
              {
                source      => $module->{full_source},
                repo        => $module->{repo},
                module_path => $module->{module_path} || '',
                ref         => $module->{ref}         || 'latest',
                type        => $module->{type}
              };

            # Add variables from schema
            foreach my $var_name ( keys %{ $schema->{properties} } ) {
                my $prop     = $schema->{properties}->{$var_name};
                my $var_info = {
                    description => $prop->{description} || '',
                    type        => $prop->{type}        || 'string',
                    required    =>
                      ( grep { $_ eq $var_name } @{ $schema->{required} } )
                    ? 1
                    : 0,
                    default    => $prop->{default},
                    validation => $prop->{custom_validation} || []
                };

                if ( $var_info->{required} ) {
                    $var_info->{value} = undef;
                }
                else {
                    $var_info->{value} = $var_info->{default};
                }

                $inputs->{variables}->{$var_name} = $var_info;
            }
        }
    }

    return $inputs;
}

sub save_analysis_results {
    print "  Saving analysis results...\n";

    my $results = {
        summary => {
            total_files      => scalar( keys %modules ),
            total_references =>
              scalar( map { @{ $modules{$_} } } keys %modules ),
            unique_modules    => scalar( keys %unique_modules ),
            generated_schemas => scalar( keys %module_schemas ),
            timestamp         => strftime( "%Y-%m-%d %H:%M:%S", localtime )
        },
        all_modules    => \%modules,
        unique_modules => \%unique_modules,
        module_schemas => \%module_schemas
    };

    # Save to admin directory
    my $output_file = "$workspace_root/admin/module_analysis.json";
    make_path( dirname($output_file) ) unless -d dirname($output_file);

    if ( !$dry_run ) {
        open( my $fh, '>', $output_file )
          or die "Cannot write $output_file: $!";
        print $fh JSON->new->pretty->encode($results);
        close $fh;
    }

    print "    Results saved to: $output_file\n";

    # Save module schemas separately
    my $schemas_file = "$workspace_root/admin/module_schemas.json";
    if ( !$dry_run ) {
        open( my $fh, '>', $schemas_file )
          or die "Cannot write $schemas_file: $!";
        print $fh JSON->new->pretty->encode( \%module_schemas );
        close $fh;
    }

    print "    Schemas saved to: $schemas_file\n";
}

sub show_summary {
    print "\n" . "=" x 60 . "\n";
    print "${BOLD}Analysis Summary${NC}\n";
    print "=" x 60 . "\n";

    my $total_files   = scalar( keys %modules );
    my $total_refs    = scalar( map { @{ $modules{$_} } } keys %modules );
    my $unique_count  = scalar( keys %unique_modules );
    my $schemas_count = scalar( keys %module_schemas );

    print "${GREEN}Total terragrunt.hcl files: $total_files${NC}\n";
    print "${GREEN}Total module references: $total_refs${NC}\n";
    print "${GREEN}Unique modules found: $unique_count${NC}\n";
    print "${GREEN}Schemas generated: $schemas_count${NC}\n";

    if ($dry_run) {
        print
"\n${YELLOW}This was a dry run - no files were actually created${NC}\n";
    }

    print "\n" . strftime( "%Y-%m-%d %H:%M:%S", localtime ) . "\n";
}

# Run main
main();
