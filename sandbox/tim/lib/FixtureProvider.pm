package FixtureProvider;

use strict;
use warnings;

use Carp qw(croak);

use Class::Tiny {
    dbh => undef,
};


sub new {
    my ($class, %args) = @_;

    my $dbh = $args{dbh};
    my $driver = $ENV{DBI_DRIVER} || $dbh->{Driver}{Name};
    $class .= "::$driver";

    (my $class_file = $class) =~ s{::}{/}g;
    $class_file .= ".pm";
    unless (eval "require $class") {
        warn $@;
        # could create a fake class that's a subclass of FixtureProvider::GenericBase_SQL
    }

    my $fp = $class->new(%args);

    return $fp;
}


1;
