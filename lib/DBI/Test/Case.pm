package DBI::Test::Case;

use strict;
use warnings;

use DBI::Mock ();

our $VERSION = "0.002";

sub requires_extended { 0 }

sub is_test_for_mocked
{
    my ( $self, $test_confs ) = @_;

    # allow DBD::NullP for DBI::Mock
    return ( $INC{'DBI.pm'} eq "mocked" and !scalar(@$test_confs) )
      || scalar grep { $_->{cat_abbrev} eq "m" } @$test_confs;
}

sub is_test_for_dbi
{
    my ( $self, $test_confs ) = @_;

    return ( -f $INC{'DBI.pm'} and !scalar(@$test_confs) )
      || scalar grep { $_->{cat_abbrev} eq "z" } @$test_confs;
}

sub filter_drivers
{
    my ( $self, $options, @test_dbds ) = @_;
    if ( $options->{CONTAINED_DBDS} )
    {
        my @contained_dbds =
          "ARRAY" eq ref( $options->{CONTAINED_DBDS} )
          ? @{ $options->{CONTAINED_DBDS} }
          : ( $options->{CONTAINED_DBDS} );
        my @supported_dbds;

        foreach my $test_dbd (@test_dbds)
        {
            @supported_dbds = ( @supported_dbds, grep { $test_dbd eq $_ } @contained_dbds );
        }

        return @supported_dbds;
    }

    return @test_dbds;
}

sub supported_variant
{
    my ( $self, $test_case, $cfg_pfx, $test_confs, $dsn_pfx, $dsn_cred, $options ) = @_;

    # allow only DBD::NullP for DBI::Mock
    if ( $self->is_test_for_mocked($test_confs) )
    {
        $dsn_cred or return 1;
        $dsn_cred->[0] eq 'dbi:NullP:' and return 1;
        return;
    }

    return 1;
}

=head1 NAME

DBI::Test::Case - base class for every test case written to be run in DBI::Test

=head1 SYNOPSIS

    package DBI::Test::Case::namespace::test::case;

    use strict;
    use warnings;

    use parent qw(DBI::Test::Case);

    use Test::More;
    use DBI::Test;

    sub filter_drivers
    {
	my ( $self, $options, @test_dbds ) = @_;

	# do own filterring and return a decision when made
	...

	# if still in doubt:
	return $self->SUPER::filter_drivers($options, @test_dbds);
    }

    sub supported_variant
    {
	my ( $self, $test_case, $cfg_pfx, $test_confs, $dsn_pfx, $dsn_cred, $options ) = @_;

	# is that combination of options and driver settings suitable for this test case?
	...

	# if still in doubt (allows handling of requires_extended, ...):
	return $self->SUPER::supported_variant($test_case, $cfg_pfx, $test_confs, $dsn_pfx, $dsn_cred, $options);
    }

    sub run_tests
    {
	my ( $self, $dsn_creds ) = @_;
	my @connect_args = @{$dsn_creds}; 

	SKIP: {
	    my $dbh = connect_ok(@connect_args, "connect to db") or skip("connect failed", 1);
	    my $sth = prepare_ok($dbh, query, "prepare sample query") or skip("prepare failed", 1);
	    execute_ok($sth, @params, "execute sample query");
	};
    }

=head1 DESCRIPTION

This is the base class for all test cases which will be populated via
DBI::Test. Intension of this class is providing base defaults for the
decisions when a test case is populated for what configuration.

=head1 METHODS

=over 4

=item I<requires_extended>

This method is called during the test population and tells the
L<DBI::Test::DSN::Provider> whether extended tests for different
driver attribute variants shall be generated.

For example, think of generic C<type_info> tests on L<DBD::CSV> - it
doesn't make a difference whether it runs with L<DBI::SQL::Nano> or
L<SQL::Statement>, neither if L<Text::CSV_XS> or L<Text::CSV> is
used for parsing.

But it makes differences when proving C<ChopBlanks> behavior, because
the underlying engine influences return values.

=item I<is_test_for_mocked>

    test::case->is_test_for_mocked($test_confs);

This method returns a true value when the given test_confs are for
a configuration relying on L<DBI::Mock>.

=item I<is_test_for_dbi>

    test::case->is_test_for_dbi($test_confs);

This method returns a true value when the given test_confs are for
a configuration relying on L<DBI>.

=item I<filter_drivers>

This method is called by L<DBI::Test::Conf/populate_tests> to remove
DBI drivers which aren't supposed to be tested in this incarnation.

    test::case->filter_drivers( $options, @test_drivers )

The options are those C<%params> L<DBI::Test::Conf/setup> got when
invoked from C<Makefile.PL>.

=item I<supported_variant>

This method is finally called before a test is really populated to
a directory. When this method returns a false value, L<DBI::Test::Conf>
jumps to the next in line.

=item I<run_tests>

This method is called from the populated test (I<*.t> file) with the
DSN and credentials as one and only argument.

=back

=head1 AUTHOR

This module is a team-effort. The current team members are

  H.Merijn Brand   (Tux)
  Jens Rehsack     (Sno)
  Peter Rabbitson  (ribasushi)

=head1 COPYRIGHT AND LICENSE

Copyright (C)2013 - The DBI development team

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut

1;
