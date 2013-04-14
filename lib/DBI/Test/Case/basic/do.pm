use strict;
use warnings;
use Test::More;

our @DB_CREDS = ('dbi:SQLite::memory:', undef, undef, {});
my %SQLS = (
  'SELECT' => 'SELECT a, b FROM x',
  'SELECT_ZERO_ROWS' => 'SELECT a, b FROM x WHERE 1 = 2',
  'INSERT' => undef
);

my $dbh = DBI->connect( @DB_CREDS );
isa_ok($dbh, 'DBI::db');
#TO BE REMOVED
$dbh->do("CREATE TABLE x(a INTEGER PRIMARY KEY)") or die $DBI::errstr;  

{ #A very basic case
  my $retval = $dbh->do($SQLS{SELECT});
  
  ok( $retval, 'dbh->do should return a true value');
}
{ #Test that the driver returns 0E0 or -1 for 0 rows
  my $retval = $dbh->do($SQLS{SELECT_ZERO_ROWS});
  ok( (defined $retval && ( $retval eq '0E0' || $retval == -1)) ? 1 : undef, '0E0 or -1 returned for zero rows select query');
}
{ #Test that the driver return > 0 for a SELECT that gives rows
  TODO : {
    local $TODO = "Make sure the query return rows";
    my $retval = $dbh->do($SQLS{SELECT});
    ok( (defined $retval && ( $retval > 0 || $retval == -1)) ? 1 : undef, 'return value for query with rows in result is > 0 or -1');      
  }
}
{ #Negative test. Check that do actually returns undef on failure
  TODO : {
    local $TODO = 'Make dbh->do fail';
    ok(!$dbh->do($SQLS{SELECT}), 'dbh->do() returns undef');
    ok($DBI::err, '$DBI::err is set on dbh->do failure');
    ok($DBI::errstr, '$DBI::errstr is set on dbh->do failure');
  }
}
done_testing();