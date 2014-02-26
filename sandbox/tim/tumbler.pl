#!/bin/env perl

=head1 prototype playground for exploring DBI Test design issues

This script generates variants of test scripts.

    Env vars that affect the DBI (DBI_PUREPERL, DBI_AUTOPROXY etc)
    |
    `- The available DBDs (eg Test::Database->list_drivers("available"))
       Current DBD is selected using the DBI_DRIVER env var
       |
       `- Env vars that affect the DBD (via DBD specific config)
          |
          `- Connection attributes (via DBD specific config)
             Set via DBI_DSN env var eg "dbi::foo=bar"

The range of variants for each is affected by the current values of the
items above. E.g., some drivers can't be used if DBI_PUREPERL is true.

=cut

use strict;
use autodie;
use Data::Dumper;
use Carp qw(croak);
use IPC::Open3;
use Symbol 'gensym';
use Config qw(%Config);

use lib 'lib';

use Context;
use WriteTestVariants;

$| = 1;
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

my $test_writer = WriteTestVariants->new(
    test_case_default_namespace => 'DBI::TestCase',
);

$test_writer->write_test_variants(
    $output_dir,
    [
        \&dbi_settings_provider,
        \&driver_settings_provider,
        \&dbd_settings_provider,
    ]
);

exit 0;


# ------


sub dbi_settings_provider {
    my ($path, $context, $tests) = @_;

    my %settings = (
        pureperl => Context->new_env_var(DBI_PUREPERL => 2),
        gofer    => Context->new_env_var(DBI_AUTOPROXY => 'dbi:Gofer:transport=null;policy=pedantic'),
    );

    # Add combinations:
    #add_settings(\%settings, get_combinations(%settings));
    # In this case returns one extra key-value pair for pureperl+gofer
    # so we'll do that manually for now:
    $settings{pureperl_gofer} = Context->new( $settings{pureperl}, $settings{gofer} );

    # add a 'null setting' that tests plain DBI with default environment
    $settings{Default} = Context->new;

    # if threads are supported then add a copy of all the existing settings
    # with 'use threads ();' added. This is probably overkill.
    if ($Config{useithreads}) {
        my $thread_setting = Context->new_module_use(threads => []);

        my %thread_settings = map {
            $_ => Context->new( $settings{$_}, $thread_setting );
        } keys %settings;

        add_settings(\%settings, \%thread_settings, undef, 'thread');
    }

    return %settings;
}


sub driver_settings_provider {
    my ($path, $context, $tests) = @_;

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

    # the dbd_settings_provider looks after filtering out drivers
    # for which we don't have a way to connect to a database

    # convert list of drivers into list of DBI_DRIVER env var settings
    return map { $_ => Context->new_env_var(DBI_DRIVER => $_) } @drivers;
}


sub dbd_settings_provider {
    my ($path, $context, $tests) = @_;

    # return variant settings to be tested for the current DBI_DRIVER

    my $driver = $context->get_env_var('DBI_DRIVER');

    require Test::Database;
    warn_once("Using Test::Database config ".Test::Database::_rcfile()."\n");

    my @tdb_handles = Test::Database->handles({ dbd => $driver });
    unless (@tdb_handles) {
        warn_once("Skipped DBD::$driver - no Test::Database dsn config using the $driver driver\n");
        return;
    }
    #warn Dumper \@tdb_handles;

    my $seqn = 0;
    my %settings;

    for my $tdb_handle (@tdb_handles) {

        my $driver_variants;

        # XXX this would dispatch to plug-ins based on the value of $driver
        # for now we just call a hard-coded sub
        if ($driver eq 'DBM') {
            $driver_variants = dbd_dbm_settings_provider($context, $tests, $tdb_handle);
        }
        else {
            $driver_variants = {
                Default => Context->new_env_var(DBI_DSN => $tdb_handle->dsn)
            };
        }

        # add DBI_USER and DBI_PASS into each variant, if defined
        for my $variant (values %$driver_variants) {
            $variant->push_var(Context->new_env_var(DBI_USER => $tdb_handle->username))
                if defined $tdb_handle->username;
            $variant->push_var(Context->new_env_var(DBI_PASS => $tdb_handle->password))
                if defined $tdb_handle->password;
        }

        # XXX would be nice to be able to use $handle->key
        my $suffix = (@tdb_handles > 1) ? ++$seqn : undef;
        add_settings(\%settings, $driver_variants, undef, $suffix);

        warn sprintf "%s has %d variants for DSN %s\n",
            $driver, scalar keys %$driver_variants, $tdb_handle->dsn;
    }

    #warn Dumper { driver => $driver, settings => \%settings };

    return %settings;
}


# --- supporting functions/hacks/stubs


sub warn_once {
    my ($msg) = @_;
    warn $msg unless our $warn_once_seen_msg->{$msg}++;
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


sub driver_is_proxy { # XXX
    my ($driver) = @_;
    return {
        Gofer => 1,
        Proxy => 1,
        Multiplex => 1,
    }->{$driver};
}

# XXX O(n^2) - better use glob() as riba or better: provide via Context methods/functions for
# sub combine_nk / cartesian
sub add_settings {
    my ($dst, $src, $prefix, $suffix) = @_;
    for my $src_key (keys %$src) {
        my $dst_key = $src_key;
        $dst_key = "$prefix-$dst_key" if defined $prefix;
        $dst_key = "$dst_key-$suffix" if defined $suffix;
        croak "Test variant setting key '$dst_key' already exists"
            if exists $dst->{$dst_key};
        $dst->{$dst_key} = $src->{$src_key};
    }
    return;
}

# XXX this should be in a separated class to be repeated when other dbm_types shall be
#     tested by plugin
#     Imagine a potential plugins Redis or MongoDB (without a serializer) ...
#     This might also be useful when testing other proxy DBD's (DBD::Multi by Dan Wright?)
sub dbd_dbm_settings_provider {
    my ($context, $tests, $tdb_handle) = @_;

    my @mldbm_types = ("");
    if ( eval { require 'MLDBM.pm' } ) {
        push @mldbm_types, qw(Data::Dumper Storable); # in CORE
        push @mldbm_types, 'FreezeThaw' if eval { require 'FreezeThaw.pm' };
        push @mldbm_types, 'YAML' if eval { require MLDBM::Serializer::YAML; };
        push @mldbm_types, 'JSON' if eval { require MLDBM::Serializer::JSON; };
    }

    my @dbm_types = grep { eval { local $^W; require "$_.pm" } }
        qw(SDBM_File GDBM_File DB_File BerkeleyDB NDBM_File ODBM_File);

    my %settings;
    for my $mldbm_type (@mldbm_types) {
        for my $dbm_type (@dbm_types) {

            my $tag = join("-", grep { $_ } $mldbm_type, $dbm_type);
            $tag =~ s/:+/_/g;

            # to pass the mldbm_type and dbm_type we use the DBI_DSN env var
            # because the DBD portion is empty the DBI still uses DBI_DRIVER env var
            # XXX really this ought to parse tdb_handle->dsn and append the
            # settings to it so as to preserve any settings in the Test::Database config.
            my $DBI_DSN = "dbi::mldbm_type=$mldbm_type,dbm_type=$dbm_type";
            $settings{$tag} = Context->new_env_var(DBI_DSN => $DBI_DSN);
        }
    }

    # Example of adding a test, in a subdir, for a single driver.
    # Because $tests is cloned in the tumbler this extra item doesn't
    # affect other contexts (but does affect all variants in this context).
    $tests->{'plugin/ExampleExtraTests.t'} = { lib => 'plug', module => 'DBM::ExampleExtraTests' };

    return \%settings;
}
