package DBI::Test::CheckUtil;

=head1 NAME

DBI::Test::CheckUtil -

=head1 SYNOPSIS

    use DBI::Test::CheckUtil;

    $sth = $dbh->prepare($statement);

    sth_ok $sth;
    h_no_err $sth;

=cut

use Test::Most;

use Exporter;
use parent 'Exporter';

our @EXPORT = qw(
    h_ok
    drh_ok dbh_ok sth_ok
    h_no_err h_has_err
);

=head1 FUNCTIONS

=head2 h_ok

=head2 drh_ok

=head2 dbh_ok

=head2 sth_ok

These functions take a single value and check that it's a valid handle (driver,
database, or statement).

=cut

sub h_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return isa_ok(shift, 'DBI::common');
}

sub drh_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return isa_ok(shift, 'DBI::dr');
}

sub dbh_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return isa_ok(shift, 'DBI::db');
}

sub sth_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return isa_ok(shift, 'DBI::st');
}


=head2 h_no_err

Takes a handle and checks that it I<is not> in an error state, i.e., that C<err>,
and C<errstr> are I<false> (undef, 0, and an empty string are ok).

If, and only if, C<err> is undef then C<state> is also checked to be false.

An extra string argument may be given and will be included in the test name
and thus the diagnostics.

=cut

sub h_no_err {
    my $h = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $pass = 1;

    h_ok $h
        or return 0;
    ok !$h->err, "err should be false @_"
        or $pass=0
        or note $h->err;
    ok !$h->errstr, "errstr should be false @_"
        or $pass=0
        or note $h->errstr;
    if (not defined $h->err) {
        ok !$h->state, "state should be false when err is undef @_"
            or $pass=0
            or note $h->state;
    }
    return $pass;
}

=head h_has_err

Takes a handle and checks that it I<is> in an error state, i.e., that C<err>,
C<errstr> and C<state> are I<true>, and that C<state> has five characters.

An extra string argument may be given and will be included in the test name
and thus the diagnostics.

=cut

sub h_has_err {
    my $h = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $pass = 1;

    h_ok $h
        or return 0;
    ok $h->err,    "err should be true @_" or $pass=0;
    ok $h->errstr, "errstr should be true @_" or $pass=0; # picky
    ok $h->state,  "state should be true if err is true @_" or $pass=0;
    like $h->state, qr/^.{5}$/, "state should be 5 characters @_" or $pass=0;

    return $pass;
}

1;
