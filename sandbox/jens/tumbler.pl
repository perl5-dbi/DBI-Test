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
use Data::Tumbler;

$| = 1;
my $input_dir  = "in";
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

my $tumbler = Data::Tumbler->new(
    consumer => \&write_test_file,
    add_context => sub {
        my ($context, $item) = @_;
        return $context->new($context, $item);
    },
);

my %tc_classes = ( MXCT => 1 );
my $plug_dir = Cwd::abs_path( File::Spec->catdir( $FindBin::RealBin, "plug" ) );

sub get_test_cases
{
    my ($template_dir) = @_;
    my %templates;
    use DDP;
    p($plug_dir);
    p(%tc_classes);
    foreach my $tc_class (keys %tc_classes)
    {
    use DDP;
	my %dbg = (
		search_dirs => $plug_dir,
		search_path => $tc_class,
		require => 0,
		);
	p(%dbg);
	my @tc_plugins = Module::Pluggable::Object->new(
		search_dirs => $plug_dir,
		search_path => $tc_class,
		require => 0,
	)->plugins;
	p(@tc_plugins);
	foreach my $name (@tc_plugins)
	{
	    my ($lib, $module) = ($1, $2) if $name =~ m/^${tc_class}::(?:(.*)::)*([^:]+)$/;
	    $templates{$name} = { lib => $lib, tc => $tc_class, module => $module };
	}
    }

    use DDP;
    p(%templates);

    return \%templates;
}

sub write_test_file {
    my ($path, $context, $leaf) = @_;

    my $dirpath = join "/", $output_dir, @$path;

    my $pre  = $context->pre_code;
    my $post = $context->post_code;

    for my $testname (sort keys %$leaf) {
        my $testinfo = $leaf->{$testname};

        $testname .= ".t" unless $testname =~ m/\.t$/;
        mkfilepath("$dirpath/$testname");

        warn "Write $dirpath/$testname\n";
        open my $fh, ">", "$dirpath/$testname";
        print $fh qq{#!perl\n};
        print $fh qq{use lib "lib";\n};
        print $fh $pre;
        print $fh "require '$testinfo->{require}';\n"
            if $testinfo->{require};
        print $fh "$testinfo->{code}\n"
            if $testinfo->{code};
        if ($testinfo->{module}) {
            print $fh "use lib '$testinfo->{lib}';\n" if $testinfo->{lib};
            print $fh "require $testinfo->{module};\n";
            print $fh "$testinfo->{module}->run_tests;\n";
        }
        print $fh $post;
        close $fh;
    }
}

my $providers = [ 
        \&oo_implementations,
        \&moox_cooperations,
    ];
my $test_cases = get_test_cases($input_dir);

$tumbler->tumble(
    # providers
    $providers,

    # path
    [],
    # context
    Context->new,
    # payload
    $test_cases,
);


exit 0;

sub mkfilepath
{
    my ($name) = @_;
    my $dirpath = dirname($name);
    mkpath($dirpath, 0) unless -d $dirpath;
}

sub oo_implementations
{
    my $use_lib_setting = Context->new_module_use(lib => [File::Spec->catdir($plug_dir, "MXCT")]);

    my %settings = (
        moose => Context->new( Context->new_module_use('Moose'), $use_lib_setting),
        moops => Context->new( Context->new_module_use('Moops'), $use_lib_setting),
        moo   => Context->new( Context->new_module_use('Moo'), $use_lib_setting),
        mo    => Context->new( Context->new_module_use('Mo'), $use_lib_setting),
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
    use DDP;
    p(%tc_classes);

    return %settings;
}

1;
