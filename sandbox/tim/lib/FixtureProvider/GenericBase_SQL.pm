package FixtureProvider::GenericBase_SQL;

use Moo;

extends 'FixtureProvider::GenericBase';

use Carp qw(croak);

use DBI::Test::Fixture;


sub get_ro_stmt_select_1r2c_si {
    # A select statement that will return 1 row comprising 2 columns which have
    # a string type with the value 'foo', and an integer type with the value
    # 42, respectively.
    # No other assumptions (eg about column names or specific types etc).
    # This fixture is the basis for most of the core sth tests.
    return DBI::Test::Fixture->new(
        statement => "select 'foo', 42"
    );
}

sub get_ro_stmt_select_1r2c_si_kV {
    # same as get_ro_stmt_select_1r2c_si but with columns named 'k' and 'V'
    # without quotes (the differing case can tell us something about how the db
    # handles cases).
    # This fixture is used to test $sth->{NAME} and related features like
    # fetchrow_hashref.
    return DBI::Test::Fixture->new(
        statement => "select 'foo' as k, 42 as V"
    );
}


1;
