package DBD::DBM::TestCase::ExampleExtraTests;

use Moo;

extends 'DBI::Test::CaseBase';

use Test::More;

sub get_subtest_method_names {
    return qw(foo);
}

sub foo {
    pass '42!'
}

1;
