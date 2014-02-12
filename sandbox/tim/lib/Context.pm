package Context;

use strict;

# a Context is an ordered list of various kinds of named values (such as env vars, our vars)
# possibly including other Context objects.
#
# Values can be looked up by name. The first match will be returned.

sub new { my $class = shift; $class = ref $class if ref $class; return bless [ @_ ], $class }

# XXX should ensure that a given type+name is only output once (the latest one)
sub pre_code  { my $self = shift; return join "", map { $_->pre_code  } reverse @$self }
sub post_code { my $self = shift; return join "", map { $_->post_code } reverse @$self }

sub get_var { # search backwards through list of settings, stop at first match
    my ($self, $name, $type) = @_;
    for my $setting (reverse @$self) {
        next unless $setting;
        my @value = $setting->get_var($name, $type);
        return $value[0] if @value;
    }
    return;
}

sub push_var { # add a var to an existing config
    my ($self, $var) = @_;
    push @$self, $var;
    return;
}

sub get_env_var { my ($self, $name) = @_; return $self->get_var($name, 'Context::EnvVar') }
sub get_our_var { my ($self, $name) = @_; return $self->get_var($name, 'Context::OurVar') }

sub new_env_var { shift->new( Context::EnvVar->new(@_) ) }
sub new_our_var { shift->new( Context::OurVar->new(@_) ) }



my $quote_value_as_perl = sub {
    my ($value) = @_;
    my $perl_value = Data::Dumper->new([$value])->Terse(1)->Purity(1)->Useqq(1)->Sortkeys(1)->Dump;
    chomp $perl_value;
    return $perl_value;
};


{
    package Context::BaseVar;
    use strict;

    # base class for a named value

    sub new {
        my ($class, $name, $value) = @_;
        return bless { name => $name, value => $value }, $class;
    }

    sub pre_code  { return '' }
    sub post_code { return '' }

    sub get_var {
        my ($self, $name, $type) = @_;
        return if $type && !$self->isa($type);  # empty list
        return if $name ne $self->{name};       # empty list
        return $self->{value};                  # scalar
    }

} # Context::BaseVar


{
    package Context::EnvVar;
    use strict;
    use parent -norequire, 'Context::BaseVar';

    # subclass representing a named environment variable

    sub pre_code {
        my $self = shift;
        my $perl_value = $quote_value_as_perl->($self->{value});
        return sprintf '$ENV{%s} = %s;%s', $self->{name}, $perl_value, "\n";
    }

    sub post_code {
        my $self = shift;
        return sprintf 'END { delete $ENV{%s} }%s', $self->{name}, "\n"; # for VMS
    }

} # Context::EnvVar


{
    package Context::OurVar;
    use strict;
    use parent -norequire, 'Context::BaseVar';

    # subclass representing a named 'our' variable

    sub pre_code {
        my $self = shift;
        my $perl_value = $quote_value_as_perl->($self->{value});
        return sprintf 'our $%s = %s;%s', $self->{name}, $perl_value, "\n";
    }

} # Context::OurVar

1;
