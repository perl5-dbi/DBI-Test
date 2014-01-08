
use strict;
use Test::More;
use DBI;

my $dbh = DBI->connect();
ok $dbh;

done_testing;

