package ExampleCase;

use strict;
use Test::More;
use parent 'DBITestCaseBase';


sub skip_me {
    plan skip_all => 'skipped!';
}


sub basic_select_prepare {
    my $self = shift;

    my $fx = $self->fixture_provider->get_ro_select_kv_1row_stmt
        or plan skip_all => 'no get_ro_select_kv_1row_stmt fixture';

    my $sth = $self->dbh->prepare($fx->statement);
    can_ok $sth, 'execute'
        or return warn "aborting subtest after execute failed";

    is $sth->err, undef;
    is $sth->errstr, undef;
    is $sth->state, '';

    note "testing attributes for select sth prior to execute";
    # specific prepared sth attributes
    TODO: {
        local $TODO = "issues with pureperl";
    ok !$sth->{Active}, 'should not be Active before execute is called';
}
    ok !$sth->{Executed};

    # generic sth attributes
    is $sth->{Type}, 'st';

    # generic attributes
    ok $sth->{Warn};
    is $sth->{Kids}, 0;
}


sub basic_select_execute {
    my $self = shift;

    my $fx = $self->fixture_provider->get_ro_select_kv_1row_stmt
        or plan skip_all => 'no get_ro_select_kv_1row_stmt fixture';

    my $sth = $self->dbh->prepare($fx->statement);
    ok $sth->execute
        or return warn "aborting subtest after execute failed";

    is $sth->err, undef;
    is $sth->errstr, undef;
    is $sth->state, '';

    note "testing attributes for select sth after execute";
    # specific attributes
    TODO: {
        local $TODO = "issues with pureperl and gofer";
    ok $sth->{Active}, 'should be Active if rows are fetchable';
    }
    ok $sth->{Executed};
    is $sth->{Kids}, 0;

    # generic attributes
    ok $sth->{Warn};
}


sub get_subtest_method_names {
    return qw(skip_me basic_select_prepare basic_select_execute);
}

1;
