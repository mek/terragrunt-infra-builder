package Deploy::Module;

use strict;
use warnings;
use Carp;

sub new {
    my ($class, %args) = @_;
    
    my $self = {
        name         => $args{name}         || '',
        description  => $args{description}  || '',
        dependencies => $args{dependencies} || [],
        tags         => $args{tags}         || {},
        priority     => $args{priority}     || 50,  # 0-100, higher = deploy earlier
        timeout      => $args{timeout}      || 600, # seconds
        pre_deploy   => $args{pre_deploy}   || sub { 1 },
        post_deploy  => $args{post_deploy}  || sub { 1 },
        validate     => $args{validate}     || sub { 1 },
        skip_if      => $args{skip_if}      || sub { 0 },
        retry        => $args{retry}        || 0,
        parallel_safe => $args{parallel_safe} // 1,
        critical     => $args{critical}     // 0,   # If true, stop all deployment on failure
        docs         => $args{docs}         || '',
        owner        => $args{owner}        || '',
        team         => $args{team}         || '',
    };
    
    bless $self, $class;
    return $self;
}

sub name         { $_[0]->{name} }
sub description  { $_[0]->{description} }
sub dependencies { $_[0]->{dependencies} }
sub tags         { $_[0]->{tags} }
sub priority     { $_[0]->{priority} }
sub timeout      { $_[0]->{timeout} }
sub pre_deploy   { $_[0]->{pre_deploy} }
sub post_deploy  { $_[0]->{post_deploy} }
sub validate     { $_[0]->{validate} }
sub skip_if      { $_[0]->{skip_if} }
sub retry        { $_[0]->{retry} }
sub parallel_safe { $_[0]->{parallel_safe} }
sub critical     { $_[0]->{critical} }
sub docs         { $_[0]->{docs} }
sub owner        { $_[0]->{owner} }
sub team         { $_[0]->{team} }

sub should_skip {
    my ($self, $context) = @_;
    return $self->{skip_if}->($context);
}

sub run_pre_deploy {
    my ($self, $context) = @_;
    return $self->{pre_deploy}->($context);
}

sub run_post_deploy {
    my ($self, $context) = @_;
    return $self->{post_deploy}->($context);
}

sub run_validate {
    my ($self, $context) = @_;
    return $self->{validate}->($context);
}

sub to_string {
    my $self = shift;
    
    my $str = "Module: " . ($self->{name} || 'unnamed') . "\n";
    $str .= "  Description: $self->{description}\n" if $self->{description};
    $str .= "  Priority: $self->{priority}\n";
    $str .= "  Dependencies: " . join(", ", @{$self->{dependencies}}) . "\n" if @{$self->{dependencies}};
    $str .= "  Tags: " . join(", ", map { "$_=$self->{tags}{$_}" } keys %{$self->{tags}}) . "\n" if %{$self->{tags}};
    $str .= "  Owner: $self->{owner}\n" if $self->{owner};
    $str .= "  Team: $self->{team}\n" if $self->{team};
    
    return $str;
}

1;
