package DBI::Test::List;

use strict;
use warnings;

our $VERSION = "0.002";

sub test_cases
{
    return qw(basic::connect basic::disconnect attributes::Error attributes::Warn);
}

=head1 NAME

DBI::Test::List - provides tests cases list for DBI::Test.

=head1 SYNOPSIS

    package DBI::Test::namespace::List;

    use strict;
    use warnings;

    use parent qw(DBI::Test::List);

    my @casegrp1 = qw(simple::case1 simple::case2);
    my @casegrp2 = qw(complex::case1 complex::case2 complex::case3);
    my @test_cases = (@casegrp1, @casegrp2);

    sub test_cases
    {
	return map { "namespace::" . $_ } @test_cases;
    }

=head1 DESCRIPTION

This class is the expected base class of every test case list class provided
by any L<DBI::Test> using derived work. The only thing currently has to be
done is overloading the I<test_cases> method and return the class names
of the test cases which should be executed.

=head1 METHODS

=over 4

=item I<test_cases>

Method which is invoked to retrieve a list of enabled test cases. This
allows authors to make decision at configure time of a distribution which
test cases shall be populated into tests.

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
