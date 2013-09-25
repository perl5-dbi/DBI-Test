package DBI::Test::Case::attributes::Error;

use strict;
use warnings;
use parent qw(DBI::Test::Case);

use Data::Dumper;

use Test::More;
use DBI::Test;

our $VERSION = "0.002";

sub supported_variant
{
    my ( $self, $test_case, $cfg_pfx, $test_confs, $dsn_pfx, $dsn_cred, $options ) = @_;
    if ( $self->is_test_for_mocked($test_confs) )
    {
        # XXX this means, SQL::Statement's DSN-Provider for NullP should extend
        #     the delivered DSN creds with the attribute below.
              defined $dsn_cred->[3]
          and defined $dsn_cred->[3]->{RootClass}
          and $dsn_cred->[3]->{RootClass} eq "SQL::Statement::Test"
          and return 1;
        return;
    }

    $dsn_cred->[0] =~ m/NullP/ and return;

    # there is only DBI and DBI::Mock ...
    return if ( scalar grep { $_->{abbrev} eq "g" } @$test_confs );    # skip Gofer proxying

    return 1;
}

sub run_test
{
    my @DB_CREDS = @{ $_[1] };

    $DB_CREDS[3]->{PrintError} = 0;
    $DB_CREDS[3]->{RaiseError} = 0;

    my $dbh = connect_ok(
                          @DB_CREDS,
                          "Connect to "
                            . Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)
                            ->Quotekeys(0)->Terse(1)->Dump()
                        );

    eval { $dbh->prepare("Junk"); };
    ok( !$@, 'Parse "Junk" RaiseError=0 (default)' ) or diag($@);

  SKIP:
    {
        # skip this test for DBI::SQL::Nano and ExampleP
	$DB_CREDS[0] =~ m/(?:ExampleP)/ and skip( "ExampleP doesn't do functions", 1 );
        $dbh->FETCH("sql_handler")
          and $dbh->FETCH("sql_handler") eq "DBI::SQL::Nano"
          and skip( "Nano doesn't do functions", 1 );
	  diag($dbh->{sql_handler});
        eval { $dbh->do("SELECT UPPER('a')"); };
        ok( !$@,           'Execute function succeeded' ) or diag($@);
        ok( !$dbh->errstr, 'Execute function no errstr' ) or diag( $dbh->errstr );
    }

    eval { $dbh->do("SELECT * FROM nonexistant"); };
    ok( !$@, 'Execute RaiseError=0' ) or diag($@);

    $DB_CREDS[3]->{RaiseError} = 1;
    $dbh = connect_ok(
                       @DB_CREDS,
                       "Connect to "
                         . Data::Dumper->new( [ \@DB_CREDS ] )->Indent(0)->Sortkeys(1)
                         ->Quotekeys(0)->Terse(1)->Dump()
                     );
    eval { $dbh->prepare("Junk"); };
    ok( $@, 'Parse "Junk" RaiseError=1' );
    {
        eval { $dbh->do("SELECT * FROM nonexistant"); };
        ok( $@,             'Execute RaiseError=1' );
        ok( $dbh->errstr(), 'Execute "SELECT * FROM nonexistant" has errstr' )
          or diag( $dbh->errstr() );
    }

    done_testing();
}

1;
