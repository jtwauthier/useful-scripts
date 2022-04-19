#!/usr/bin/env perl

use strictures 2;
use feature 'say';

use MetaCPAN::Client;

my $app = sub {
	my ( $args ) = @_;
	my $term     = $args->[0];

	if ( ! defined $term ) {
		die "No search term specified\n";
	}

	warn "Searching for $term\n";

	my $client   = MetaCPAN::Client->new();
	my %query    = ( name => "*$term*" );
	my $distros  = $client->distribution( \%query );

	while ( my $distro = $distros->next() ) {
		say $distro->name();
	}

	return;
};

$app->( \@ARGV );
