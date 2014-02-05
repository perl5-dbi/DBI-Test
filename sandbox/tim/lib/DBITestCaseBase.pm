package DBITestCaseBase;

# This is all very rough, experimental, and may change completely

use strict;

use Test::More;

use Try::Tiny;
use Carp qw(croak);


# this method is kept very simple because some tests might want to
# override this and/or find_and_call_subtests to reuse the fixtures
# for multiple similar test runs, e.g. with different connection attributes
sub run_tests {
    my ($class, %args) = @_;

    my $instance = bless { %args } => $class;

    try {
        $instance->setup;
        $instance->find_and_call_subtests;
    }
    catch {
        fail "Caught exception: $_";
    }
    finally {
        $instance->teardown;
    };

    return;
}


sub setup {
    my $self = shift;
    pass "base setup";
    return;
}


sub teardown {
    my $self = shift;
    pass "base teardown";
    done_testing(); # XXX here?
    return;
}

sub find_and_call_subtests {
    my ($self) = @_;
    my @test_method_names = $self->get_subtest_method_names;
    for my $test_method_name (@test_method_names) {
        my $ref = $self->can($test_method_name)
            or croak "panic: method $test_method_name seen but doesn't exist";
        subtest $test_method_name => $ref;
    }
}

1;
