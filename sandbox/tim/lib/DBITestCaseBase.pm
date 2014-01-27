package DBITestCaseBase;

# This is all very rough, experimental, and may change completely

use strict;

use Test::More;

use Try::Tiny;


# this method is kept very simple because some tests might want to
# override this and/or find_and_call_subtests to reuse the fixtures
# for multiple similar test runs, e.g. with different connection attributes
sub run_tests {
    my ($class) = @_;

    try {
        $class->setup;
        $class->find_and_call_subtests;
    }
    catch {
        fail "Caught exception: $_";
    }
    finally {
        $class->teardown;
    };

    return;
}


sub setup {
    pass "base setup";
    return;
}


sub teardown {
    pass "base teardown";
    done_testing(); # XXX here?
    return;
}

sub find_and_call_subtests {
    my ($class) = @_;
}

1;
