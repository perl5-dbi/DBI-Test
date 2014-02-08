package FixtureProvider::GenericBase;

use strict;
use warnings;

use Carp qw(croak);


use Class::Tiny {
    dbh => undef,
};


sub get_dbit_temp_name {
    my ($self, $name) = @_;
    croak "invalid name '$name'"
        unless $name =~ /^\w+$/;

    my $pid = $$;
    my (undef,undef,$hour,$mday,$mon,$year) = localtime(time);
    my $yymmddhh = sprintf "%02d%02d%02d%02d", $year % 100, $mon+1, $mday, $hour;

    my $temp_name = sprintf "dbit1_%s_%d__%s", $yymmddhh, $pid, $name;

    return $temp_name;
}
# could also provide methods to:
# - supply a regex that matches the get_dbit_temp_name name
# - parse a get_dbit_temp_name to extract especially the yymmddhh
# - drop all get_dbit_temp_name tables older than N hours (0=all)

1;
