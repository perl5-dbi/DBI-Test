#!/bin/env perl

use strict;
use autodie;
use File::Find;
use File::Path;
use File::Basename;
use Data::Dumper;

use lib 'lib';

use Context;
use Tumbler;

my $input_dir  = "in";
my $output_dir = "out";

my $templates = get_templates($input_dir);

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
    # Returns the original settings plus extras created by combining.
    # In this case returns one extra key-value pair, i.e.:
    # $settings{pureperl_gofer} = Context->new( $settings{pureperl}, $settings{gofer} );
#   %settings = add_combinations(%settings);

    # add a 'null setting' that tests plain DBI with default environment
    $settings{plain} = Context->new;

    return %settings;
}


sub driver_settings_provider {
    my ($context, $tests) = @_;

    # return a setting for each driver that can be tested in the current context

    require DBI;
    my @drivers = DBI->available_drivers; # Test::Database->list_drivers("available");

    # these filters could be implemented as per-driver test plugins
    # that respond to the $context

    # filter out proxy drivers
    @drivers = grep { !driver_is_proxy($_) } @drivers;

    # filter out non-pureperl drivers if testing with DBI_PUREPERL
    @drivers = grep { driver_is_pureperl($_) } @drivers
        if $context->get_env_var('DBI_PUREPERL');

    # convert list of drivers into list of DBI_DRIVER env var settings
    return map { $_ => Context->new_env_var(DBI_DRIVER => $_) } @drivers;
}


sub dbd_settings_provider {
    my ($context, $tests) = @_;

    # return variant settings to be tested for the current DBI_DRIVER

    my $driver = $context->get_env_var('DBI_DRIVER');
    my %settings;

    # this would dispatch to plug-ins based on the value of

    if ($driver eq 'DBM') {

        my @mldbm_types = ("");
        if ( eval { require 'MLDBM.pm' } ) {
            push @mldbm_types, qw(Data::Dumper Storable); # in CORE
            push @mldbm_types, 'FreezeThaw' if eval { require 'FreezeThaw.pm' };
            push @mldbm_types, 'YAML' if eval { require MLDBM::Serializer::YAML; };
            push @mldbm_types, 'JSON' if eval { require MLDBM::Serializer::JSON; };
        }

        my @dbm_types = grep { eval { local $^W; require "$_.pm" } }
            qw(SDBM_File GDBM_File DB_File BerkeleyDB NDBM_File ODBM_File);

        for my $mldbm_type (@mldbm_types) {
            for my $dbm_type (@dbm_types) {

                my $tag = join("-", grep { $_ } $mldbm_type, $dbm_type);
                $tag =~ s/:+/_/g;
                $settings{$tag} = Context->new_our_var(DBD_DBM_SETTINGS => {
                    mldbm_type => $mldbm_type,
                    dbm_types  => $dbm_type,
                });

            }
        }

        # example of adding a test, in a subdir, for a single driver
        $tests->{"deeper/path/example.t"} = { code => "use Test::More; pass(); done_testing;" };
    }

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
    return 1 if $driver eq 'Gofer' || $driver eq 'Proxy';
    return 0;
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
    mkpath($dirpath, 1) unless -d $dirpath;
}
