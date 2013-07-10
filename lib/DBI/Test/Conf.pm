package DBI::Test::Conf;

use strict;
use warnings;

use Carp qw(croak);
use Config;

use Cwd            ();
use File::Basename ();
use File::Path     ();
use File::Spec     ();

use Module::Pluggable::Object ();

my $cfg_plugins;

sub cfg_plugins
{
    defined $cfg_plugins and return @{$cfg_plugins};

    my $finder = Module::Pluggable::Object->new(
                                                 search_path => ["DBI::Test"],
                                                 require     => 1,
                                                 only        => qr/::Conf$/,
                                                 inner       => 0
                                               );
    my @plugs = grep { $_->isa("DBI::Test::Conf") } $finder->plugins();
    $cfg_plugins = \@plugs;

    return @{$cfg_plugins};
}

my %conf = (
    default => {
                 category   => "mock",
                 cat_abbrev => "m",
                 abbrev     => "b",
                 init_stub  => qq(\$ENV{DBI_MOCK} = 1;),
                 match      => {
                            general   => qq(require DBI;),
                            namespace => [""],
                          },
                 name => "Unmodified Test",
               },
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
                                                 require     => 1,
                                                 only        => qr/::List$/,
                                                 inner       => 0
                                               );
    my @plugs = grep { $_->isa("DBI::Test::List") } $finder->plugins();
    $tc_plugins = \@plugs;

    return @{$tc_plugins};
}

sub alltests
{
    my ($self) = @_;
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

# simplified copy from Math::Cartesian::Product
# Copyright (c) 2009 Philip R Brenan.
# This module is free software. It may be used, redistributed and/or modified under the same terms as Perl itself.

sub cartesian
{
    my @C = @_;    # Lists to be multiplied
    my @c = ();    # Current element of cartesian product
    my @P = ();    # Cartesian product
    my $n = 0;     # Number of elements in product

    @C or return;  # Empty product

    # Generate each cartesian product when there are no prior cartesian products.

    my $p;
    $p = sub {
        if ( @c < @C )
        {
            for ( @{ $C[@c] } )
            {
                push @c, $_;
                &$p();
                pop @c;
            }
        }
        else
        {
            my $p = [@c];
            push @P, $p;
        }
    };

    &$p();

    @P;
}

sub create_test
{
    my ( $self, $test_case, $prefix, $test_confs ) = @_;

    my $test_file = $test_case;
    $test_file =~ s,::,/,g;
    $test_file = File::Spec->catfile( "t", $test_file . ".t" );
    my $test_dir = File::Basename::dirname($test_file);

    $test_file = File::Basename::basename($test_file);
    $prefix and $test_file = join( "_", $prefix, $test_file );
    $test_file = File::Spec->catfile( $test_dir, $test_file );

    -d $test_dir or File::Path::make_path($test_dir);
    open( my $tfh, ">", $test_file ) or croak("Cannot open \"$test_file\": $!");
    my $init_stub = join( "\n", map { $_->{init_stub} } @$test_confs );
    $init_stub and $init_stub = sprintf( <<EOS, $init_stub );
BEGIN {
%s
}
EOS

    # XXX how to deal with namespaces here and how do they affect generated test names?
    my $test_case_ns = "DBI::Test::Case::$test_case";
    my $test_case_code = sprintf( <<EOC, $init_stub );
#!$^X\n
%s
use DBI::Mock;
use DBI::Test::DSN::Provider;

use ${test_case_ns};

my \$test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds("${test_case_ns}");
${test_case_ns}->run_test(\$test_case_conf);
EOC

    print $tfh "$test_case_code\n";
    close($tfh);

    return $test_dir;
}

sub create_prefixes
{
    my ( $self, $allconf ) = @_;
    my %pfx_hlp;
    my %pfx_lst;

    foreach my $cfg ( values %$allconf )
    {
        push( @{ $pfx_hlp{ $cfg->{cat_abbrev} } }, $cfg );
    }

    foreach my $cfg_id ( keys %pfx_hlp )
    {
        my $n = scalar( @{ $pfx_hlp{$cfg_id} } );
        my @combs = map { combine_nk( $n, $_ ); } ( 1 .. $n );
        scalar @combs or next;
        $pfx_lst{$cfg_id} = {
            map {
                my @cfgs = map { $pfx_hlp{$cfg_id}->[$_] } @{$_};
                my $pfx = "${cfg_id}v" . join( "", map { $_->{abbrev} } @cfgs );
                $pfx => \@cfgs
              } @combs
        };
    }

    my %pfx_direct = map { %{$_} } values %pfx_lst;
    %pfx_hlp = %pfx_lst;
    %pfx_lst = ( "" => [] );
    do
    {
        my @pfx   = keys %pfx_hlp;
        my $n     = scalar(@pfx);
        my @combs = map { combine_nk( $n, $_ ); } ( 1 .. $n );
        foreach my $comb (@combs)
        {
            my @cfgs = cartesian( map { [ keys %{ $pfx_hlp{ $pfx[$_] } } ] } @$comb );
            foreach my $cfg (@cfgs)
            {
                my $_pfx = join( "_", @$cfg );
                $pfx_lst{$_pfx} = [ map { @{ $pfx_direct{$_} } } @$cfg ];
            }
        }
    } while (0);

    return %pfx_lst;
}

sub populate_tests
{
    my ( $self, $alltests, $allconf ) = @_;
    my %test_dirs;

    my %pfx_cfgs = $self->create_prefixes($allconf);
    foreach my $pfx ( keys %pfx_cfgs )
    {
        foreach my $test (@$alltests)
        {
            my $test_dir = $self->create_test( $test, $pfx, $pfx_cfgs{$pfx} );
            $test_dirs{$test_dir} = 1;
        }
    }

    return map { File::Spec->catfile( $_, "*.t" ) } keys %test_dirs;
}

sub setup
{
    my ($self) = @_;

    my %allconf = $self->allconf();
    # from DBI::Test::{NameSpace}::List->test_cases()
    my @alltests = $self->alltests();

    return $self->populate_tests( \@alltests, \%allconf );
}

=head1 NAME

DBI::Test::Conf - provides variants configuration for DBI::Test

=head1 DESCRIPTION

This module provides the configuration of variants for tests
generated from DBI::Test::Case list.

=head1 AUTHOR

This module is a team-effort. The current team members are

  H.Merijn Brand   (Tux)
  Jens Rehsack     (Sno)
  Peter Rabbitson  (ribasushi)
  Joakim TE<0x00f8>rmoen   (trmjoa)

=head1 COPYRIGHT AND LICENSE

Copyright (C)2013 - The DBI development team

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut

1;
