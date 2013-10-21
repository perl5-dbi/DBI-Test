
use strict;
use Data::Dumper;
use Storable qw(dclone);
use Template::Tiny;

{ package Setting::Env;

use Class::Tiny { type => 'env', name => undef, value => undef };

sub pre_code {
    my $self = shift;
    my $value = sprintf 'q{%s}', $self->{value}; # TODO needs proper perl quoting
    return sprintf '$ENV{%s} = %s;%s', $self->{name}, $value, "\n";
}
sub post_code {
    my $self = shift;
    return sprintf 'delete $ENV{%s};%s', $self->{name}, "\n"; # for VMS
}

} # Setting::Env


# tumbler(
#   $providers,  - array of code refs returning key-value pairs of variants
#   $leaf,       - data passed to $providers (which may edit it) and $consumer
#   $consumer,   - code ref called for each variant at each level
#   $path,       - array of current variant names, one for each level of provider
#   $context     - array of current variant values, one for each level of provider
# )

sub tumbler {                              # this code is generic
    my ($providers, $leaf, $consumer, $path, $context) = @_;

    my @providers = @$providers;

    if (not @providers) { # no more providers in this context
        $consumer->($path, $context, $leaf);
        return $leaf;
    }

    $leaf = dclone($leaf); # so provider can alter it

    my %variants = (shift @providers)->($context, $leaf);

    if (not %variants) { # no variants at this level

        return tumbler(\@providers, $leaf, $consumer, $path, $context);
    }
    else {

        my %tree;
        for my $name (sort keys %variants) {

            $tree{$name} = tumbler(
                \@providers, $leaf, $consumer,
                [ @$path, $name ],
                [ @$context, $variants{$name} ],
            );
        }
        return \%tree;
    }
}


# ------

my $tree = tumbler(
    [   # providers
        \&dbi_settings_provider,
        \&driver_settings_provider,
    ],
    {   # 'templates'
        "foo.t" => "PRE\nfoo\nPOST\n",
        "bar.t" => "PRE\nbar\nPOST\n",
    },
    sub { # consumer
        my ($path, $context, $leaf) = @_;
        my $dirpath = join "/", @$path;

        my $pre  = join "", map { $_ ? $_->pre_code  : () } @$context;
        my $post = join "", map { $_ ? $_->post_code : () } reverse @$context;

        for my $testname (keys %$leaf) {
            my $body = $leaf->{$testname};
            $body =~ s/PRE\n/$pre/;
            $body =~ s/POST\n/$post/;
            warn "\nWrite $dirpath/$testname:\n$body\n";
        }
    },
    [ ], # path
    [ ], # context
);
#warn Dumper $tree;


exit 0;


# ------

sub new_env_setting {
    my ($name, $value) = @_;
    return Setting::Env->new(name => $name, value => $value);
}
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


sub dbi_settings_provider {

    my %settings = (
        pureperl => new_env_setting(DBI_PUREPERL => 2),
        gofer    => new_env_setting(DBI_AUTOPROXY => 'dbi:Gofer:transport=null;policy=pedantic'),
    );

    # Add combinations:
    # Returns the original settings plus extras created by combining.
    # In this case returns one extra key-value pair, i.e.:
    # $settings{pureperl_gofer} = new_multi_setting( $settings{pureperl}, $settings{gofer} );
#   %settings = add_combinations(%settings);

    # add a 'null setting' that tests plain DBI with default environment
    $settings{plain} = undef;

    return %settings;
}


sub driver_settings_provider {
    my ($settings_context, $tests) = @_;

    require DBI;
    my @drivers = DBI->available_drivers; # Test::Database->list_drivers("available");

    # these filters could be implemented as per-driver test plugins
    # that respond to the $settings_context

    # filter out proxy drivers
    @drivers = grep { !driver_is_proxy($_) } @drivers;

    # filter out non-pureperl drivers if testing with DBI_PUREPERL
    @drivers = grep { driver_is_pureperl($_) } @drivers
        # if $settings_context->get_env('DBI_PUREPERL'); # would be better
        if grep { $_ && $_->name eq 'DBI_PUREPERL' && $_->value } @$settings_context;

    return map { $_ => new_env_setting(DBI_DRIVER => $_) } @drivers;
}


