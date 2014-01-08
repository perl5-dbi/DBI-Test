package Context;

use strict;

# a Context is an ordered list of various kinds of named values (such as env vars, our vars)
# possibly including other Context objects.
#
# Values can be looked up by name. The first match will be returned.

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

sub get_env_var { my ($self, $name) = @_; return $self->get_var($name, 'Context::EnvVar') }
sub get_our_var { my ($self, $name) = @_; return $self->get_var($name, 'Context::OurVar') }

sub new_env_var { shift; Context::EnvVar->new(@_) }
sub new_our_var { shift; Context::OurVar->new(@_) }


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
        my $perl_value = ::quote_value_as_perl($self->{value});
        return sprintf '$ENV{%s} = %s;%s', $self->{name}, $perl_value, "\n";
    }

    sub post_code {
        my $self = shift;
        return sprintf 'delete $ENV{%s};%s', $self->{name}, "\n"; # for VMS
    }

} # Context::EnvVar


{
    package Context::OurVar;
    use strict;
    use parent -norequire, 'Context::BaseVar';

    # subclass representing a named 'our' variable

    sub pre_code {
        my $self = shift;
        my $perl_value = ::quote_value_as_perl($self->{value});
        return sprintf 'our $%s = %s;%s', $self->{name}, $perl_value, "\n";
    }

} # Context::OurVar

1;
