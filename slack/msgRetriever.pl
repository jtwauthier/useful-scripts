#!/usr/bin/env perl

use strictures 2;
use 5.030;
use experimental 'postderef';

package My::App {

  use Moo;

  use DateTime;
  use FindBin '$RealBin';
  use YAML 'LoadFile';
  use Data::Dump 'dump';
  use File::Spec;
  use Types::Standard qw(HashRef InstanceOf Str);
  use WebService::Slack::WebApi;

  has config => (
    isa     => HashRef,
    is      => 'ro',
    builder => '_build_config',
    lazy    => 1,
  );

  has client => (
    isa     => InstanceOf['WebService::Slack::WebApi'],
    is      => 'ro',
    builder => '_build_client',
    lazy    => 1,
  );

  has domain => (
    isa     => Str,
    is      => 'rw',
    default => '',
    lazy    => 1,
  );

  sub run {
    my ( $self, @args ) = @_;
    my $link            = shift @args;
    my $data            = $self->_parse_link( $link );

    $self->domain( $data->{domain} );

    my $client          = $self->client();
    my %options         = ( channel => $data->{channel} );
    my $channel         =  $client->conversations->info( %options )->{channel};
    my $channel_name    = $channel->{name};
    my $tz              = $self->config->{time_zone};

    %options            = ( epoch => $data->{msg_ts}, time_zone => $tz );

    my $msg_dt          = DateTime->from_epoch( %options );

    %options            = ( epoch => $data->{reply_ts}, time_zone => $tz );

    my $reply_dt        = DateTime->from_epoch( %options );

    %options            = (
      channel => $data->{channel},
      ts      => $data->{msg_ts},
      oldest  => $data->{reply_ts},
      latest  => $data->{reply_ts},
      limit   => 1,
      inclusive => 1,
    );

    my $response        = $client->conversations->replies( %options );
    my @messages        = $response->{messages}->@*;
    my $text            = $messages[0]->{text};

    my $user            = $client->users->info(
      user => $messages[0]->{user}
    )->{user};

    my $user_name       = $user->{real_name};

    say sprintf(
      "%s sent:\n%s\nto %s in %s on %s",
      $user_name,
      $text,
      $channel_name,
      $data->{domain},
      $reply_dt,
    );

    exit 0;
  }

  sub _parse_link {
    my ( $self, $link ) = @_;

    my @parts           = (
      $link =~ m{https://(\w+)\.[\w.]+/archives/([^/]+)/p(\d+)(?:\?thread_ts=(\d.+))?}
    );

    my $ts              = substr( $parts[2], 0, -6 )
       . '.' . substr( $parts[2], -6);

    my $thread_ts       = $parts[3];

    my %data            = (
      domain   => $parts[0],
      channel  => $parts[1],
      msg_ts   => $ts,
      reply_ts => $ts,
    );

    $data{msg_ts}       = $thread_ts if ( defined $thread_ts );

    return \%data;
  }

  sub _build_config {
    my ( $self ) = @_;
    my $file     = File::Spec->catdir( $RealBin, 'slack.yml' );
    my $config   = LoadFile( $file );

    return $config;
  }

  sub _build_client {
    my ( $self ) = @_;
    my $domain   = $self->domain();
    my $data     =  $self->config->{team}->{$domain};

    unless ( defined $data ) {
      say 'Cannot find config data for the specified slack team';

      exit 0;
    }

    my $token    = $data->{token};

    unless ( defined $token ) {
      say 'Cannot find an auth token for the specified slack team';

      exit 0;
    }

    my $client   = WebService::Slack::WebApi->new( token => $token );

    return $client;
  }
}

my $app = My::App->new();

$app->run( @ARGV );
