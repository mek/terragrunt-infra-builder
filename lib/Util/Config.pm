package Util::Config;

use strict;
use warnings;
use Carp;

use YAML::Tiny;
use Util::Color;

use Sub::Exporter -setup => {
  exports => ['get_config_value'],
};

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