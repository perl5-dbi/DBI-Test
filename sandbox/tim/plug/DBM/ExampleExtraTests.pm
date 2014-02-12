package DBM::ExampleExtraTests;

use strict;
use Test::More;
use parent 'DBITestCaseBase';

sub get_subtest_method_names {
    return qw(foo);
}

sub foo {
    pass '42!'
}

1;
