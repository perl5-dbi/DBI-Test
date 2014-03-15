package DBI::TestCase::dbh_ro::SelectMultiThread;

use strict;
use Config qw(%Config);
use Test::More;

use base 'DBI::Test::CaseBase';


my $threads = 4;

sub setup {

    plan skip_all => "threads not supported"
        if !$Config{useithreads} || $] < 5.008001;

    plan skip_all => "threads not loaded in context"
        unless $threads::VERSION && $threads::VERSION;

    require DBI;

    shift->SUPER::setup(@_);

    # use an explicit plan here as protection against thread-induced strangeness
    plan tests => 4 + 6 * $threads;
}


sub get_subtest_method_names {
    return qw(test_with_threads);
}


sub test_with_threads {
    my ($test) = @_;

    # alter a DBI global - we'll check it has the same value in threads
    $DBI::neat_maxlen = 12345;
    cmp_ok($DBI::neat_maxlen, '==', 12345, '... assignment of neat_maxlen was successful');

    # connect via connect_cached
    my $parent_dbh = $test->_connect;
    isnt $parent_dbh, $test->dbh, '_connect should return a different dbh to the original';
    is   $parent_dbh, $test->_connect, '_connect should return the same dbh (via connect_cached)';
    $test->dbh($parent_dbh); # use the new dbh as the default for this test

    # start multiple threads, each running the test subroutine 
    my @thr;
    foreach (1..$threads) {
        push @thr, threads->create( sub { _test_a_thread($test) } )
            or die "thread->create failed ($!)";
    }

    # join all the threads
    foreach my $thread (@thr) {
        # provide a little insurance against thread scheduling issues (hopefully)
        # http://www.nntp.perl.org/group/perl.cpan.testers/2009/06/msg4369660.html
        eval { select undef, undef, undef, 0.2 };

        $thread->join;
    }

    pass('... all tests have passed');
}


sub _connect {
    my ($self) = @_;
    my $dbh = $self->dbi_connect_hook->($self, {
       dbi_connect_method => 'connect_cached'
    });
    return $dbh;
}


sub _test_a_thread {
    my ($self) = @_;

    cmp_ok($DBI::neat_maxlen, '==', 12345, 'DBI::neat_maxlen should hold its value');

    # use the parent's dbi_connect_hook to get a thread-local $dbh
    my $dbh = $self->_connect;
    isa_ok( $dbh, 'DBI::db' );
    isnt($dbh, $self->dbh, 'new $dbh should be different from parent dbh');
 
    # use the parent's fixture_provider_hook but our thread-local $dbh
    my $fixture_provider = $self->fixture_provider_hook->($self, $dbh);

    SKIP: {
	# skip seems broken with threads (5.8.3)
	# skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;

        cmp_ok($dbh->{Driver}->{Kids}, '==', 1, '... the Driver has one Kid')
		unless $DBI::PurePerl && ok(1);
    }

    # RT #77137: a thread created from a thread was crashing the interpreter
    my $subthread = threads->new(sub { 42 });
    # provide a little insurance against thread scheduling issues (hopefully)
    # http://www.nntp.perl.org/group/perl.cpan.testers/2009/06/msg4369660.html
    eval { select undef, undef, undef, 0.2 };
    is $subthread->join(), 42;

    # perform a simple select
    my $fx = $fixture_provider->get_ro_stmt_select_1r2c_si;
    my $rows = $dbh->selectall_arrayref($fx->statement);
    {
        $TODO = "broken under gofer - needs investigating"
            if ($ENV{DBI_AUTOPROXY}||'') =~ /:Gofer/;
    is_deeply($rows, [ [ 'foo', 42 ] ], 'selectall_arrayref should return expected data');
    }

    return;
}

1;
