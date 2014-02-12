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
use Tumbler;

$| = 1;
my $input_dir  = "in";
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

my $stash = Package::Stash->new("Context");
$stash->add_symbol('&new_class_use', sub { shift->new( Context::UseClass->new(@_) ) } );

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

tumbler(
    # providers
    $providers,

    # templates
    $test_cases,

    # consumer
    \&write_test_file,

    # path
    [],
    # context
    Context->new,
);


exit 0;

sub quote_value_as_perl
{
    my ($value) = @_;
    my $perl_value = Data::Dumper->new([$value])->Terse(1)->Purity(1)->Useqq(1)->Sortkeys(1)->Dump;
    chomp $perl_value;
    return $perl_value;
}

sub mkfilepath
{
    my ($name) = @_;
    my $dirpath = dirname($name);
    mkpath($dirpath, 0) unless -d $dirpath;
}

{
    package Context::UseClass;
    use strictures;
    use parent -norequire, 'Context::BaseVar';

    # base class for a named value

    sub pre_code {
        my $self = shift;
        my $perl_value = "ARRAY" eq ref($self->{value}) ? "(" . join(", ", ( map { ::quote_value_as_perl($_) } @{$self->{value}} ) ) . ")" : "";
        return sprintf 'use $%s%s;%s', $self->{name}, $perl_value, "\n";
    }

} # Context::UseClass

sub oo_implementations
{
    my %settings = (
        moose => Context->new( Context->new_class_use(lib => [File::Spec->catdir($plug_dir, "MXCT")]), Context->new_class_use('Moose')),
        moops => Context->new( Context->new_class_use(lib => [File::Spec->catdir($plug_dir, "MXCT")]), Context->new_class_use('Moops')),
        moo => Context->new( Context->new_class_use(lib => [File::Spec->catdir($plug_dir, "MXCT")]), Context->new_class_use('Moo')),
        mo  => Context->new( Context->new_class_use(lib => [File::Spec->catdir($plug_dir, "MXCT")]), Context->new_class_use('Mo')),
    );

    return %settings;
}

sub moox_cooperations
{
    my %settings;
    
    eval {
	Module::Runtime::require_module('MooX::Options');
	$settings{mxo} = Context->new( Context->new_class_use(lib => [File::Spec->catdir($plug_dir, "MXCOT")]), Context->new_class_use('MooX::Options') );
	$tc_classes{MXCOT} = 1;
    };
    use DDP;
    p(%tc_classes);

    return %settings;
}

1;
