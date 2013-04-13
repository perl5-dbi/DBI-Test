package DBI::Test::Conf;

use strict;
use warnings;

my %setup = (
#    p => {	name => "DBI::PurePerl",
#	    match => qr/^\d/,
#	    add => [ '$ENV{DBI_PUREPERL} = 2',
#		     'END { delete $ENV{DBI_PUREPERL}; }' ],
#    },
):

sub setup
{
    return %setup;
}

1;
