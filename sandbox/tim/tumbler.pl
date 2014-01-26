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
use File::Find;
use File::Path;
use File::Basename;
use Data::Dumper;

use lib 'lib';

use Context;
use Tumbler;

$| = 1;
my $input_dir  = "in";
my $output_dir = "out";

my $templates = get_templates($input_dir);

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

tumbler(
    # providers
    [ 
        \&dbi_settings_provider,
        \&driver_settings_provider,
        \&dbd_settings_provider,
    ],

    # templates
    $templates,

    # consumer
    \&write_test_file,

    # path
    [],
    # context
    Context->new,
);


sub get_templates {
    my ($template_dir) = @_;
    my %templates;

    find(sub {
        next unless m/\.t$/;
        my $name = $File::Find::name;
        $name =~ s!\Q$template_dir\E/!!;
        $templates{ $name } = { require => $File::Find::name };
    }, $template_dir);

    return \%templates;
}



sub write_test_file {
    my ($path, $context, $leaf) = @_;

    my $dirpath = join "/", $output_dir, @$path;

    my $pre  = $context->pre_code;
    my $post = $context->post_code;

    for my $testname (sort keys %$leaf) {
        my $testinfo = $leaf->{$testname};

        mkfilepath("$dirpath/$testname");

        warn "Write $dirpath/$testname\n";
        open my $fh, ">", "$dirpath/$testname";
        print $fh "#!perl\n";
        print $fh $pre;
        print $fh "require '$testinfo->{require}';\n" if $testinfo->{require};
        print $fh "$testinfo->{code}\n" if $testinfo->{code};
        print $fh $post;
        close $fh;
    }
}


exit 0;


# ------


sub dbi_settings_provider {

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

    return %settings;
}


sub driver_settings_provider {
    my ($context, $tests) = @_;

    # return a DBI_DRIVER env var setting for each driver that can be tested in
    # the current context

    require DBI;
    my @drivers = DBI->available_drivers();

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
    my ($context, $tests) = @_;

    # return variant settings to be tested for the current DBI_DRIVER

    my $driver = $context->get_env_var('DBI_DRIVER');

    require Test::Database;
    my @tdb_handles = Test::Database->handles({ dbd => $driver });
    unless (@tdb_handles) {
        warn "Skipped $driver driver - no Test::Database dsn config using the $driver driver\n";
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
            $driver_variants = dbd_dbm_settings_provider($context, $tests);
        }
        else {
            # if the driver has no variants then we supply a dummy one
            # (else this context would be skipped)
            $driver_variants = { Default => Context->new };
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
    }

    #warn Dumper { driver => $driver, settings => \%settings };

    return %settings;
}


# --- supporting functions/hacks/stubs


sub driver_is_pureperl { # XXX
    my ($driver) = @_;
    return 0 if $driver eq 'SQLite';
    return 1;
}

sub driver_is_proxy { # XXX
    my ($driver) = @_;
    return {
        Gofer => 1,
        Proxy => 1,
        Multiplex => 1,
    }->{$driver};
}

sub quote_value_as_perl {
    my ($value) = @_;
    my $perl_value = Data::Dumper->new([$value])->Terse(1)->Purity(1)->Useqq(1)->Sortkeys(1)->Dump;
    chomp $perl_value;
    return $perl_value;
}

sub mkfilepath {
    my ($name) = @_;
    my $dirpath = dirname($name);
    mkpath($dirpath, 0) unless -d $dirpath;
}

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


sub dbd_dbm_settings_provider {
    my ($context, $tests) = @_;

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
            my $DBI_DSN = "dbi::mldbm_type=$mldbm_type,dbm_type=$dbm_type";
            $settings{$tag} = Context->new_env_var(DBI_DSN => $DBI_DSN);
        }
    }

    # Example of adding a test, in a subdir, for a single driver.
    # Because $tests is cloned in the tumbler this extra item doesn't
    # affect other contexts, but does affect all variants in this context.
    $tests->{"deeper/path/example.t"} = { code => "use Test::More; pass(); done_testing;" };

    return \%settings;
}
