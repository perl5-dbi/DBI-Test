package ExampleCase;

use strict;
use Test::More;
use parent 'DBITestCaseBase';


sub foo {
    plan skip_all => 'skipped!';
}

sub bar {
    pass;
}


sub get_subtest_method_names {
    return qw(foo bar);
}

1;
