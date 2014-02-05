package DBITestCaseBase;

# This is all very rough, experimental, and may change completely

use strict;

use Test::More;

use Try::Tiny;
use Carp qw(croak);

use Class::Tiny {

    dbh => undef,
    dbi_connect_hook => sub { sub {
        require DBI;
        return DBI->connect(); # uses env vars
    } },

    sth => undef,

    fixture_provider => undef,
    fixture_provider_hook => sub { sub {
        require FixtureProvider;
        return FixtureProvider->new(dbh => shift->dbh);
    } },
};


=head2 run_tests

The default run_tests method calls L</new> (passing any supplied arguments) to
create an instance, then calls L</setup>, L</find_and_call_subtests>, and
L</teardown> on that instance.

The method can be overridden in the test module to run all the subtests methods
with different configurations. For example:

    sub run_tests {
        my $class = shift;
        $class->SUPER::run_tests(foo => 42);
        $class->SUPER::run_tests(foo => 43);
        $class->SUPER::run_tests(foo => 44);
    }

=cut

sub run_tests {
    my ($class, %args) = @_;

    my $self = $class->new(%args);

    # perhaps use lives_ok instead of try/catch
    try {
        $self->setup;
        $self->find_and_call_subtests;
    }
    catch {
        fail "Caught exception: $_";
    }
    finally {
        $self->teardown;
    };

    return;
}



sub setup {
    my $self = shift;

    unless ($self->dbh) {
        my $dbh = $self->dbi_connect_hook->($self);
        $self->dbh($dbh);
    }
    can_ok $self->dbh, qw(err errstr state set_err prepare do disconnect);

    unless ($self->fixture_provider) {
        my $fixture_provider = $self->fixture_provider_hook->($self);
        $self->fixture_provider($fixture_provider);
    }
    can_ok $self->fixture_provider, qw(get_ro_select_kv_1row_stmt);

    pass "base setup";
    return;
}


sub teardown {
    my $self = shift;
    pass "base teardown";
    done_testing(); # XXX implicitly here or explicitly in the test module?
    return;
}


sub find_and_call_subtests {
    my ($self) = @_;

    my @test_method_names = $self->get_subtest_method_names;
    for my $test_method_name (@test_method_names) {
        $self->_call_subtest($test_method_name);
    }
}


sub _call_subtest {
    my ($self, $test_method_name) = @_;

    my $ref = $self->can($test_method_name)
        or croak "panic: method $test_method_name seen but doesn't exist";

    subtest $test_method_name => sub { $ref->($self) };

    return;
}


1;
