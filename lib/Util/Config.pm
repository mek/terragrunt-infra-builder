package Util::Config;

use strict;
use warnings;
use Carp;
use Exporter 'import';

use YAML::Tiny;
use Util::Color;

# use Sub::Exporter -setup => {
#  exports => ['get_config_value'],
#};

our @EXPORT = qw(get_config_value);

my $instance;

sub new {
  my ($class, %args) = @_;
  my $self = {
    file => $args{file} || 'config/manage-config.yaml',
    data => {},
    verbose => $args{verbose} || 0,
  };
  bless $self, $class;
  $self->load_configuration();
  return $self;
}

sub load_configuration {
  # load configuration file
  my $self = shift;
  if (-f $self->{file}) {
    eval {
      $self->{data} = YAML::Tiny->read($self->{file});
      $self->{data} = $self->{data}->[0];  # YAML::Tiny returns array reference
    };
    if ($@) {
      warn "${YELLOW}Warning: Error loading configuration file $self->{file}: $@${NC}\n";
      warn "${YELLOW}Using default configuration${NC}\n";
      $self->set_default_config();
    } else {
      print "${GREEN}Configuration loaded from: $self->{file}${NC}\n" if $self->{verbose};
    } 
  } else {
    $self->set_default_config();
    print "${YELLOW}Using default configuration (no config file found at $self->{file})${NC}\n" if $self->{verbose};
  }
}

sub set_default_config {
  my $self->{data} = {
    directories => {
      environments => "envs",
      projects => "projects",
      modules => "modules",
      environment_structure => {
        regional_placement => "direct",
        default_project => "h2g2",
      }
    },
    templates => {
      base_path => "templates",
      environment => "env",
      region => "region",
      zone => "zone",
      project => "project"
    },
    files => {
      environment => "env.hcl",
      region => "region.hcl",
      project => "project.hcl",
      terragrunt => "terragrunt.hcl"
    },
    zones => {
      allowed => {
        "us-east-1" => "ohio",
        "us-west-2" => "oregon",
        "us-west-1" => "california",
        "eu-west-1" => "ireland",
        "eu-central-1" => "frankfurt",
        "ap-southeast-1" => "singapore",
        "ap-northeast-1" => "tokyo"
      }
    }
  }
}

sub get_config_value {
  my ($path) = @_;
  $instance ||= __PACKAGE__->new();
  $instance->_get($path); 
}

sub set_instance {
  my ($class, $new_instance) = @_;

  if (defined $new_instance && !$new_instance->isa(__PACKAGE__)) {
    croak "Argument to set_instance() must be an instance of " .  __PACKAGE__;
  }

  $instance = $new_instance;

  return $instance;
}

sub _get {
  my ($self,$path) = @_;
  my @keys = split(/\./, $path);
  my $value = $self->{data};
  
  foreach my $key (@keys) {
    return undef unless defined $value && ref($value) eq 'HASH';
    $value = $value->{$key};
  }

  return $value;
}

1;

__END__

=head1 NAME

Util::Config - A module for managing configuration data using YAML files.

=head1 SYNOPSIS

  use Util::Config;
  
  # Retrieve a configuration value using a dot-separated path
  my $value = get_config_value('directories.environments');

=head1 DESCRIPTION

The Util::Config module provides an interface to manage configuration settings
stored in YAML files. It supports loading configuration from a specified file
or a default location and offers convenient methods to retrieve configuration
values.

=head1 METHODS

=head2 new

  my $config = Util::Config->new(file => 'path/to/config.yaml', verbose => 1);

Creates a new Util::Config instance. Accepts the following parameters:

=over 4

=item B<file>

Specifies the configuration file to load. Defaults to 'config/manage-config.yaml'.

=item B<verbose>

Enables verbose output if set to a true value.

=back

=head2 get_config_value

  my $value = get_config_value('path.to.value');

Retrieves a configuration value using a dot-separated path. Automatically handles
loading the configuration from the specified file or default location.

=head1 CONFIGURATION STRUCTURE

=over 4

=item B<directories>

Contains directory settings such as environments, projects, and modules.

=item B<templates>

Specifies template paths used within the configuration.

=item B<files>

Defines standard file names used in various infrastructure components.

=item B<zones>

Lists allowed zones and their shorthand identifiers for various AWS regions.

=back

=head1 AUTHOR

Copyright (c) 2017-2025 Mat Kovach <mek@mek.cc>

=head1 LICENSE

Licensed under the MIT License.

=cut