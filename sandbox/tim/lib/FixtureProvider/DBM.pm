package FixtureProvider::DBM;

use strict;
use warnings;

use parent 'FixtureProvider::GenericBase_SQL';


sub get_ro_stmt_select_1r2c_si {
    return shift->get_ro_stmt_select_1r2c_si_kV(@_);
}

sub get_ro_stmt_select_1r2c_si_kV {
    my $provider = shift;

    # XXX table name conventions and table management?

    my $dbh = $provider->dbh;
    $dbh->do("create table dbit_dbm_test1 (k text, V integer)");
    $dbh->do("insert into dbit_dbm_test1 values ('foo', 42)");

    return Fixture->new(
        statement => "select k, V from dbit_dbm_test1",
        demolish => sub {
            $provider->dbh->do("drop table dbit_dbm_test1");
        },
    );
}


1;
