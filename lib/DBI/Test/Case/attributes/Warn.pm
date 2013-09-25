package DBI::Test::Case::attributes::Warn;

use strict;
use warnings;
use parent qw(DBI::Test::Case);

use Test::More;
use DBI::Test;

our $VERSION = "0.002";

#Check that warn is enabled by default
sub run_test
{
    my @DB_CREDS = @{$_[1]};

    my $dbh = connect_ok (@DB_CREDS, "basic connect");
  
    ok($dbh->{Warn}, '$dbh->{Warn} is true');
    ok($dbh->FETCH('Warn'), '$dbh->FETCH(Warn) is true');

    done_testing();
}

1;
