#!/bin/env perl

use strictures;

use autodie;
use Cwd qw();
use File::Find;
use File::Path;
use File::Spec qw();
use File::Basename;
use Data::Dumper;
use Package::Stash qw();
use Module::Runtime;
use Module::Pluggable::Object;

use lib '../tim/lib';
use lib 'lib';
use FindBin qw();

use Context;
use WriteTestVariants;

$| = 1;
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;


my %tc_classes = ( MXCT => 1 );
my $plug_dir = Cwd::abs_path( File::Spec->catdir( $FindBin::RealBin, "plug" ) );


my $test_writer = WriteTestVariants->new(
    test_case_default_namespace => 'DBI::TestCase',
    test_case_search_dirs => [ $plug_dir ],
    test_case_search_path => [ keys %tc_classes ],
);

$test_writer->write_test_variants(
    $output_dir,
    [ 
        \&oo_implementations,
        \&moox_cooperations,
    ],
);

exit 0;


sub oo_implementations
{
    my %settings = (
        moose => Context->new_module_use('Moose'),
        moops => Context->new_module_use('Moops'),
        moo   => Context->new_module_use('Moo'),
        mo    => Context->new_module_use('Mo'),
    );

    return %settings;
}

sub moox_cooperations
{
    my ($path, $context, $tests) = @_;

    my %settings;
    
    eval {
	Module::Runtime::require_module('MooX::Options');
        my $use_lib_setting = Context->new_module_use(lib => [File::Spec->catdir($plug_dir, "MXCOT")]);

	$settings{mxo} = Context->new( Context->new_module_use('MooX::Options'), $use_lib_setting);
	$tc_classes{MXCOT} = 1;
    };
    warn $@ if $@;
    use DDP;
    #p(%tc_classes);

    return %settings;
}

1;
