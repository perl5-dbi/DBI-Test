package DBI::Test::Conf;

use strict;
use warnings;

use Config;

use Module::Pluggable::Object;

my $plugins;

sub plugins
{
    defined $plugins and return @{$plugins};

    my $finder = Module::Pluggable::Object->new(
                                                 search_dir => "DBI::Test",
                                                 only       => qr/::Conf$/,
                                                 inner      => 0
                                               );
    my @plugs = grep { $_->isa("DBI::Test::Conf") } $finder->plugins();
    $plugins = \@plugs;

    return @{$plugins};
}

my %conf = (
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
    my @plugins = $self->plugins();
    foreach my $plugin (@plugins)
    {
        # Hash::Merge->merge( ... )
	%allconf = ( %allconf, $plugin->conf() );
    }
    return %allconf;
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

sub populate_tests
{
    my ( $self, $alltests, $allconf ) = @_;
    my %test_variants;

    # decide what needs doing
    while ( my ( $test_name, $test_variant ) = each( %{ $allconf->{test_variants} } ) )
    {
        $test_variant->{disabled} and next;
        $test_variants{$test_name} = $test_variant;
    }

    # expand for all combinations
    my @all_keys = ();
    my @tv_keys = (); #sort map { } ...;
    join( "v", values %test_variants );
    while (@tv_keys)
    {
        my $cur_key = shift @tv_keys;
        last if ( 1 < length $cur_key );
        my @new_keys;
        foreach my $remain (@tv_keys)
        {
            push @new_keys, $cur_key . $remain unless $remain =~ /$cur_key/;
        }
        push @tv_keys,  @new_keys;
        push @all_keys, @new_keys;
    }

    my %uniq_keys;
    foreach my $key (@all_keys)
    {
        @tv_keys = sort split //, $key;
        my $ordered = join( '', @tv_keys );
        $uniq_keys{$ordered} = 1;
    }
    @all_keys = sort { length $a <=> length $b or $a cmp $b } keys %uniq_keys;

    # do whatever needs doing
    if ( keys %test_variants )
    {
        # XXX need to convert this to work within the generated Makefile
        # so 'make' creates them and 'make clean' deletes them
        opendir DIR, 't' or die "Can't read 't' directory: $!";
        my @tests = grep { /\.t$/ } readdir DIR;
        closedir DIR;

        foreach my $test_combo (@all_keys)
        {
            @tv_keys = split //, $test_combo;
            my @test_names = map { $test_variants{$_}->{name} } @tv_keys;
            printf "Creating test wrappers for " . join( " + ", @test_names ) . ":\n";
            my @test_matches = map { $test_variants{$_}->{match} } @tv_keys;
            my @test_adds;
            foreach my $test_add ( map { $test_variants{$_}->{add} } @tv_keys )
            {
                push @test_adds, @$test_add;
            }
            my $v_type = $test_combo;
            $v_type = 'x' . $v_type if length($v_type) > 1;

          TEST:
            foreach my $test ( sort @tests )
            {
                foreach my $match (@test_matches)
                {
                    next TEST if $test !~ $match;
                }
                my $usethr = ( $test =~ /(\d+|\b)thr/ && $] >= 5.008 && $Config{useithreads} );
                my $v_test = "t/zv${v_type}_$test";
                my $v_perl = ( $test =~ /taint/ ) ? "perl -wT" : "perl -w";
                printf "%s %s\n", $v_test, ($usethr) ? "(use threads)" : "";
                open PPT, ">$v_test" or warn "Can't create $v_test: $!";
                print PPT "#!$v_perl\n";
                print PPT "use threads;\n" if $usethr;
                print PPT "$_;\n" foreach @test_adds;
                print PPT "require './t/$test'; # or warn \$!;\n";
                close PPT or warn "Error writing $v_test: $!";
            }
        }
    }

}

sub setup
{
    my ($self) = @_;

    my %allconf  = $self->allconf();
    # from DBI::Test::{NameSpace}::List->test_cases()
    my %alltests = $self->alltests();

    $self->populate_tests( \%alltests, \%allconf );
}

1;
