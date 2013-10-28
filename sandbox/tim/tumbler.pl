
use strict;
use Data::Dumper;
use Storable qw(dclone);
use Template::Tiny;

{ package Setting::Base;
sub new {
    my ($class, $name, $value) = @_;
    return bless { name => $name, value => $value }, $class;
}
sub pre_code {
    return ''
}
sub post_code {
    return ''
}
sub get_var {
    my ($self, $name, $type) = @_;
    return if $type && !$self->isa($type);  # empty list
    return if $name ne $self->{name};       # empty list
    return $self->{value};                  # scalar
}

} # Setting::Base

{ package Setting::EnvVar; use parent -norequire, 'Setting::Base';

sub pre_code {
    my $self = shift;
    my $perl_value = ::quote_value_as_perl($self->{value});
    return sprintf '$ENV{%s} = %s;%s', $self->{name}, $perl_value, "\n";
}
sub post_code {
    my $self = shift;
    return sprintf 'delete $ENV{%s};%s', $self->{name}, "\n"; # for VMS
}

} # Setting::EnvVar

{ package Setting::OurVar; use parent -norequire, 'Setting::Base';

sub pre_code {
    my $self = shift;
    my $perl_value = ::quote_value_as_perl($self->{value});
    return sprintf 'our $%s = %s;%s', $self->{name}, $perl_value, "\n";
}

} # Setting::OurVar

{ package Context; # a list of settings

sub new { my $class = shift; return bless [ @_ ], $class }

sub pre_code  { my $self = shift; return join "", map { $_->pre_code  } reverse @$self }
sub post_code { my $self = shift; return join "", map { $_->post_code } reverse @$self }

sub get_var { # search backwards through list of settings
    my ($self, $name, $type) = @_;
    for my $setting (reverse @$self) {
        next unless $setting;
        my @value = $setting->get_var($name, $type);
        return $value[0] if @value;
    }
    return;
}

sub get_env_var { my ($self, $name) = @_; return $self->get_var($name, 'Setting::EnvVar') }
sub get_our_var { my ($self, $name) = @_; return $self->get_var($name, 'Setting::OurVar') }

} # Context


# tumbler(
#   $providers,  - array of code refs returning key-value pairs of variants
#   $leaf,       - opaque data passed to $providers (which may edit it) and to $consumer
#   $consumer,   - code ref called for each path of variants
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

    # clone the $leaf so provider can alter it for the consumer
    # at and below this point in the tree of variants
    $leaf = dclone($leaf);

    my %variants = (shift @providers)->($context, $leaf);

    if (not %variants) {

        # no variants at this level so continue to next level of provider

        return tumbler(\@providers, $leaf, $consumer, $path, $context);
    }
    else {

        # for each variant in turn, call the next level of provider
        # with the name and value of the variant appended to the
        # path and context.

        my %tree;
        for my $name (sort keys %variants) {

            $tree{$name} = tumbler(
                \@providers, $leaf, $consumer,
                [ @$path, $name ],
                Context->new($context, $variants{$name}),
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
        \&dbd_settings_provider,
    ],
    {   # 'templates' (a cloned copy is passed to the producers and consumer)
        # This is clearly just a hack for demo purposes.
        # Something like Template::Tiny or Text::Template could be adopted
        # or our own lightweight object that could act as an adaptor.
        "foo.t" => "PRE\nfoo\nPOST\n",
        "bar.t" => "PRE\nbar\nPOST\n",
    },
    sub { # consumer
        my ($path, $context, $leaf) = @_;
        my $dirpath = join "/", @$path;

        my $pre  = $context->pre_code;
        my $post = $context->post_code;

        for my $testname (keys %$leaf) {
            my $body = $leaf->{$testname};
            $body =~ s/PRE\n/$pre/;
            $body =~ s/POST\n/$post/;
            warn "\nWrite $dirpath/$testname:\n$body\n";
        }
    },
    [ ], # path
    Context->new(), # context
);
#warn Dumper $tree;


exit 0;


# ------


sub dbi_settings_provider {

    my %settings = (
        pureperl => Setting::EnvVar->new(DBI_PUREPERL => 2),
        gofer    => Setting::EnvVar->new(DBI_AUTOPROXY => 'dbi:Gofer:transport=null;policy=pedantic'),
    );

    # Add combinations:
    # Returns the original settings plus extras created by combining.
    # In this case returns one extra key-value pair, i.e.:
    # $settings{pureperl_gofer} = Context->new( $settings{pureperl}, $settings{gofer} );
#   %settings = add_combinations(%settings);

    # add a 'null setting' that tests plain DBI with default environment
    $settings{plain} = Setting::Base->new;

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
    return map { $_ => Setting::EnvVar->new(DBI_DRIVER => $_) } @drivers;
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
                $settings{$tag} = Setting::OurVar->new(DBD_DBM_SETTINGS => {
                    mldbm_type => $mldbm_type,
                    dbm_types  => $dbm_type,
                });

            }
        }

        # example of adding a test, in a subdir, for a single driver
        $tests->{"deeper/path/example.t"} = "PRE\nexample extra test in subdir\nPOST\n";
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
