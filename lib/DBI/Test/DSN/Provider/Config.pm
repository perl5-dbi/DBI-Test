package DBI::Test::DSN::Provider::Config;

use strict;
use warnings;

my $json;

BEGIN {
    foreach my $mod (qw(JSON JSON::PP))
    {
	eval "require $mod";
	$@ and next;
	$json = $mod->new();
	last;
    }

    $json or die "";
}

1;

=head1 NAME

DBI::Test::DSN::Provider::Config - provides DSN based on config file

=head1 DESCRIPTION

This DSN provider delivers connection attributes based on a config
file.

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
