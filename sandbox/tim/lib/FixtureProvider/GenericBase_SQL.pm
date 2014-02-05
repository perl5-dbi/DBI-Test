package FixtureProvider::GenericBase_SQL;

use strict;
use warnings;

use parent 'FixtureProvider::GenericBase';

use Carp qw(croak);

use Fixture;


sub get_ro_select_kv_1row_stmt {
    return Fixture->new(
        statement => "select 'foo' as k, 42 as v"
    );
}


1;
