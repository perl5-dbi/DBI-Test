package DBIT_sth_ro::BasicPrepareExecuteSelect;

# Test the basic prepare + execute + fetchrow sequence
# of a valid select statement that returns 1 row.
#
# Other tests needed (just noting here for reference):
# select returning 0 rows
# select with syntax error (may be detected at prepare or execute)
# all fetch* methods
#
# Need to consider structure and naming conventions for test modules.
# Need to consider a library of test subroutines

use strict;
use Test::More;
use parent 'DBITestCaseBase';


sub _h_no_error {
    my ($self, $h) = @_;

    # XXX allow info and warn states to pass?
    # (but log them in stats for info?)
    is $h->err, undef;
    is $h->errstr, undef;
    is $h->state, '';
}


sub basic_prepare_execute_select_ro {
    my $self = shift;

    my $fx = $self->fixture_provider->get_ro_stmt_select_1r2c_si
        or plan skip_all => 'no get_ro_stmt_select_1r2c_si fixture';

    my $sth = $self->dbh->prepare($fx->statement);
    can_ok $sth, 'execute'
        or return warn "aborting subtest after prepare failed";

    $self->_h_no_error($sth);

    note "testing attributes for select sth prior to execute";
    # specific prepared sth attributes
    TODO: {
        local $TODO = "issues with pureperl - fixed in DBI 1.632";
    ok !$sth->{Active}, 'should not be Active before execute is called';
    }
    ok !$sth->{Executed};

    # generic sth attributes
    is $sth->{Type}, 'st';

    # generic attributes
    ok $sth->{Warn};
    is $sth->{Kids}, 0;


    ok $sth->execute
        or return warn "aborting subtest after execute failed";

    $self->_h_no_error($sth);

    note "testing attributes for select sth after execute";
    # specific attributes
    TODO: {
        local $TODO = "issues with gofer TBD";
    ok $sth->{Active}, 'should be Active if rows are fetchable';
    }
    ok $sth->{Executed};
    is $sth->{Kids}, 0;

    # generic attributes
    ok $sth->{Warn};
}


sub get_subtest_method_names {
    return qw(basic_prepare_execute_select_ro);
}

1;