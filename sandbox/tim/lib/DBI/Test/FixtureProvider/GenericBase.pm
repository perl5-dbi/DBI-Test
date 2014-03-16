package DBI::Test::FixtureProvider::GenericBase;

use Moo;

use Carp qw(croak);

has dbh => (
    is => 'rw',
);


(my $default_fixture_provider = __PACKAGE__)
    =~ s/::\w+$/::GenericSQL/;


sub get_fixture_provider_for_dbh {
    my ($class, %args) = @_;

    my $dbh = $args{dbh};
    my $driver = $ENV{DBI_DRIVER} || $dbh->{Driver}{Name};
    $class =~ s/\bGenericBase$/$driver/;

    unless (eval "require $class") {

        (my $class_file = $class) =~ s{::}{/}g;
        $class_file .= ".pm";

        if ($@ =~ m/Can't locate \Q$class_file\E/) {
            eval qq{
                package $class;
                use Moo;
                extends '$default_fixture_provider';
                \$INC{'$class_file'} = __FILE__;
                warn "No $class found so using $default_fixture_provider (failures are likely)\n";
            };
            die @$ if $@;
        }
        else {
            die $@;
        }
    }

    my $fp = $class->new(%args);

    return $fp;
}


# TODO Move name management methods into a role
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
