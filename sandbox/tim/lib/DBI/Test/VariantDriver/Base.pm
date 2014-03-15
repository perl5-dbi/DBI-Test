package DBI::Test::VariantDriver::Base;

use strict;

use IPC::Open3;
use Symbol 'gensym';
use Test::Database;

use DBI::Test::VariantUtil qw(add_variants warn_once);

sub provider {
    my ($self, $path, $context, $tests, $variants) = @_;

    # return a DBI_DRIVER env var setting for each driver that can be tested in
    # the current context

    require DBI;
    my @drivers = DBI->available_drivers();

    # filter out broken drivers here
    @drivers = grep { driver_is_loadable($_) } @drivers;

    # filter out proxy drivers here - they should be handled by
    # dbi_settings_provider() creating contexts using DBI_AUTOPROXY
    @drivers = grep { !driver_is_proxy($_) } @drivers;

    # filter out non-pureperl drivers if testing with DBI_PUREPERL
    @drivers = grep { driver_is_pureperl($_) } @drivers
        if $context->get_env_var('DBI_PUREPERL');

    for my $driver (@drivers) {

        my @tdb_handles = Test::Database->handles({ dbd => $driver })
            or warn_once("Skipped DBD::$driver - no Test::Database dsn config using the $driver driver\n");

        my $seqn = 0;
        my %settings;

        for my $tdb_handle (@tdb_handles) {

            # XXX would be nice to be able to use $handle->key
            my $suffix = ++$seqn;

            my %settings;
            $settings{"$driver-$suffix"} = $context->new(
                $context->new_env_var(DBI_DRIVER => $driver),
                $context->new_meta_info(tdb_handle => $tdb_handle),
            );

            add_variants($variants, \%settings);
        }
    }


    return;
}


sub driver_is_proxy { # XXX
    my ($driver) = @_;
    return {
        Gofer => 1,
        Proxy => 1,
        Multiplex => 1,
        Multi => 1,
    }->{$driver};
}


sub driver_is_pureperl { # XXX
    my ($driver) = @_;

    my $cache = \our %_driver_is_pureperl_cache;
    $cache->{$driver} = check_if_driver_is_pureperl($driver)
        unless exists $cache->{$driver};

    return $cache->{$driver};
}


sub driver_is_loadable {
    my ($driver) = @_;

    my $cache = \our %_driver_is_loadable_cache;
    unless (exists $cache->{$driver}) {
        my $errmsg = $cache->{$driver} = get_driver_load_error($driver);
        if ($errmsg) {
            $errmsg =~ s/ \(\@INC contains: .*?\)( at .*? line \d+)?//;
            $errmsg =~ s/\n.*//s;
            warn "Ignoring DBD::$driver: $errmsg\n";
        }
    }

    return ($cache->{$driver} ? 0 : 1);
}


sub check_if_driver_is_pureperl {
    my ($driver) = @_;

    local $ENV{DBI_PUREPERL} = 2; # force DBI to be pure-perl
    my $errmsg = get_driver_load_error($driver);

    # if it ran ok than it's pureperl
    return 1 if not defined $errmsg;

    # else if the error was the expected one for XS
    # then we're sure it's not pureperl
    return 0 if $errmsg =~ /Unable to get DBI state function/;

    # we should never get here
    warn "Can't tell if DBD::$driver is pure-perl. Loading via DBI::PurePerl failed in an unexpected way: $errmsg\n";

    return 0; # assume not pureperl and let tests fail if they're going to
}


sub get_driver_load_error {
    my ($driver) = @_;

    local $ENV{DBI_DRIVER} = $driver; # just to avoid injecting name into cmd
    my $cmd = $^X.q{ -MDBI -we 'DBI->install_driver($ENV{DBI_DRIVER}); exit 0'};

    my $pid = open3(my $wtrfh, my $rdrfh, my $errfh = gensym, $cmd);
    waitpid( $pid, 0 );
    my $errmsg = join "\n", <$errfh>;

    if ($? == 0 && !$errmsg) {
        return undef;  # typical success
    }
    elsif ($? == 0) {
        warn "Loading $driver generated a warning: $errmsg\n";
        return undef;  # treat as success here
    }
    return $errmsg;
}


1;
