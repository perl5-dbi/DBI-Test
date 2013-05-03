package DBI::Test;

require 5.008001;
use strict;
use warnings;

our $VERSION = "0.001";

=head1 NAME

DBI::Test - Test suite for DBI API

=cut

require Test::Builder;

1;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

This module aims at a transparent test suite for the DBI API
to be used from both sides of the API (DBI and DBD) to check
if the provided functionality is working and complete.

=head1 GOAL

=head2 TODO

=head2 Source

Recent changes can be (re)viewed in the public GIT repository at
GitHub L<https://github.com/perl5-dbi/DBI-Test>
Feel free to clone your own copy:

 $ git clone https://github.com/perl5-dbi/DBI-Test.git DBI-Test

=head2 Contact

We are discussing issues on the DBI development mailing list 1) and on IRC 2)

 1) The DBI team <dbi-dev@perl.org>
 2) irc.perl.org/6667 #dbi

=head2 Reporting bugs

=head1 TEST SUITE

=head1 EXAMPLES

=head1 DIAGNOSTICS

=head1 SEE ALSO

 DBI        - Database independent interface for Perl
 DBI::DBD   - Perl DBI Database Driver Writer's Guide
 Test::More - yet another framework for writing test scripts

=head1 AUTHOR

This module is a team-effort. The current team members are

  H.Merijn Brand   (Tux)
  Jens Rehsack     (Sno)
  Peter Rabbitson  (ribasushi)
  Joakim TE<0x00f8>rmoen   (trmjoa)

=head1 COPYRIGHT AND LICENSE

Copyright (C)2013 - The DBI development team

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut
