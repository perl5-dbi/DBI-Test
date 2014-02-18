package FixtureProvider;

use strict;
use warnings;

use Carp qw(croak);

use Class::Tiny {
    dbh => undef,
};

my $default_fixture_provider = 'FixtureProvider::GenericBase_SQL';


sub new {
    my ($class, %args) = @_;

    my $dbh = $args{dbh};
    my $driver = $ENV{DBI_DRIVER} || $dbh->{Driver}{Name};
    $class .= "::$driver";

    (my $class_file = $class) =~ s{::}{/}g;
    $class_file .= ".pm";
    unless (eval "require $class") {
        if ($@ =~ m/Can't locate \Q$class_file\E/) {
            warn "No $class so using $default_fixture_provider (failures are likely)\n";
            eval qq{
                package $class;
                use parent '$default_fixture_provider';
                \$INC{'$class_file'} = __FILE__;
            };
            die @$ if $@;
        }
        else {
            warn $@;
        }
    }

    my $fp = $class->new(%args);

    return $fp;
}


1;
