package DBI::Test::Conf;

use strict;
use warnings;

use Carp qw(croak);
use Config;

use Cwd ();
use File::Basename ();
use File::Path ();
use File::Spec ();

use Module::Pluggable::Object ();

my $cfg_plugins;

sub cfg_plugins
{
    defined $cfg_plugins and return @{$cfg_plugins};

    my $finder = Module::Pluggable::Object->new(
                                                 search_path => ["DBI::Test"],
						 require    => 1,
                                                 only       => qr/::Conf$/,
                                                 inner      => 0
                                               );
    my @plugs = grep { $_->isa("DBI::Test::Conf") } $finder->plugins();
    $cfg_plugins = \@plugs;

    return @{$cfg_plugins};
}

my %conf = (
    default => {
	category => undef,
	cat_abbrev => "",
	abbrev => "",
	prefix => "", # XXX kick it out when we calculate the prefixes
	init_stub => "",
	match => ".*",
	name => "Unmodified Test",
    },
    #    ...
    #    p => {	name => "DBI::PurePerl",
    #	    match => qr/^\d/,
    #	    add => [ '$ENV{DBI_PUREPERL} = 2',
    #		     'END { delete $ENV{DBI_PUREPERL}; }' ],
    #    },
);

sub conf { %conf; }

sub allconf
{
    my ($self)  = @_;
    my %allconf = $self->conf();
    my @plugins = $self->cfg_plugins();
    foreach my $plugin (@plugins)
    {
        # Hash::Merge->merge( ... )
	%allconf = ( %allconf, $plugin->conf() );
    }
    return %allconf;
}

my $tc_plugins;

sub tc_plugins
{
    defined $tc_plugins and return @{$tc_plugins};

    my $finder = Module::Pluggable::Object->new(
                                                 search_path => ["DBI::Test"],
						 require    => 1,
                                                 only       => qr/::List$/,
                                                 inner      => 0
                                               );
    my @plugs = grep { $_->isa("DBI::Test::List") } $finder->plugins();
    $tc_plugins = \@plugs;

    return @{$tc_plugins};
}

sub alltests
{
    my ($self)  = @_;
    my @alltests;
    my @plugins = $self->tc_plugins();
    foreach my $plugin (@plugins)
    {
        # Hash::Merge->merge( ... )
	@alltests = ( @alltests, $plugin->test_cases() );
    }
    return @alltests;
}

sub combine_nk
{
    my ( $n, $k ) = @_;
    my @indx;
    my @result;

    @indx = map { $_ } ( 0 .. $k - 1 );

  LOOP:
    while (1)
    {
        my @line = map { $indx[$_] } ( 0 .. $k - 1 );
        push( @result, \@line ) if @line;
        for ( my $iwk = $k - 1; $iwk >= 0; --$iwk )
        {
            if ( $indx[$iwk] <= ( $n - 1 ) - ( $k - $iwk ) )
            {
                ++$indx[$iwk];
                for my $swk ( $iwk + 1 .. $k - 1 )
                {
                    $indx[$swk] = $indx[ $swk - 1 ] + 1;
                }
                next LOOP;
            }
        }
        last;
    }

    return @result;
}

sub create_test
{
    my ($self, $test_case, $test_conf) = @_;

    my $test_file = $test_case;
    $test_file =~ s,::,/,g;
    $test_file = File::Spec->catfile("t", $test_file . ".t" );
    my $test_dir = File::Basename::dirname($test_file);

    $test_file = File::Basename::basename($test_file);
    $test_file = $test_conf->{prefix} . $test_file;
    $test_file = File::Spec->catfile($test_dir, $test_file);

    -d $test_dir or File::Path::make_path($test_dir);
    open(my $tfh, ">", $test_file) or croak("Cannot open \"$test_file\": $!");
    my $test_case_code = <<EOC;
#!$^X\n"

$test_conf->{init_stub}

use ${test_case};

${test_case}->run_test;
EOC

    print $tfh "$test_case_code\n";
    close($tfh);

    return $test_dir;
}

sub populate_tests
{
    my ( $self, $alltests, $allconf ) = @_;
    my %test_dirs;

    foreach my $conf (values %$allconf)
    {
	foreach my $test (@$alltests)
	{
	    my $test_dir = $self->create_test($test, $conf);
	    $test_dirs{$test_dir} = 1;
	}
    }

    return map { File::Spec->catfile( $_, "*.t" ) } keys %test_dirs;
}

sub setup
{
    my ($self) = @_;

    my %allconf  = $self->allconf();
    # from DBI::Test::{NameSpace}::List->test_cases()
    my @alltests = $self->alltests();

    return $self->populate_tests( \@alltests, \%allconf );
}

1;
