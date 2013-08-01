package DBI::Test::Case;

use strict;
use warnings;

use DBI::Mock ();

sub requires_extended { 0 }

sub supported_variant
{
    my ( $self, $test_case, $cfg_pfx, $test_confs, $dsn_pfx, $dsn_cred, $options ) = @_;

    # allow only DBD::NullP for DBI::Mock
    if( $INC{'DBI.pm'} eq "mocked" or grep { $_->{cat_abbrev} eq "m" } @$test_confs )
    {
	$dsn_cred or return 1;
	$dsn_cred->[0] eq 'dbi:NullP:' and return 1;
	return;
    }

    return 1;
}

1;
