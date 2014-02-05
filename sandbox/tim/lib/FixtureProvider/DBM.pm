package FixtureProvider::DBM;

use strict;
use warnings;

use parent 'FixtureProvider::GenericBase_SQL';


sub get_ro_select_kv_1row_stmt {
    my $provider = shift;

    my $dbh = $provider->dbh;
    $dbh->do("create table dbit_dbm_test1 (k text, v integer)");
    $dbh->do("insert into dbit_dbm_test1 values ('foo', 42)");

    return Fixture->new(
        statement => "select k, v from dbit_dbm_test1",
        demolish => sub {
            $provider->dbh->do("drop table dbit_dbm_test1");
        },
    );
}


1;
