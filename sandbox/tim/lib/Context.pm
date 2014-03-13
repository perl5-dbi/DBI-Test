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

sub get_env_var    { my ($self, $name) = @_; return $self->get_var($name, 'Context::EnvVar') }
sub get_our_var    { my ($self, $name) = @_; return $self->get_var($name, 'Context::OurVar') }
sub get_module_use { my ($self, $name) = @_; return $self->get_var($name, 'Context::ModuleUse') }
sub get_meta_info  { my ($self, $name) = @_; return $self->get_var($name, 'Context::MetaInfo') }

sub new_env_var    { my ($self, $n, $v, %e) = @_; $self->new( Context::EnvVar->new(%e, name => $n, value => $v) ) }
sub new_our_var    { my ($self, $n, $v, %e) = @_; $self->new( Context::OurVar->new(%e, name => $n, value => $v) ) }
sub new_module_use { my ($self, $n, $v, %e) = @_; $self->new( Context::ModuleUse->new(%e, name => $n, value => $v) ) }
sub new_meta_info  { my ($self, $n, $v, %e) = @_; $self->new( Context::MetaInfo->new(%e, name => $n, value => $v) ) }




{
    package Context::BaseItem;
    use strict;
    require Carp;

    # base class for a named value

    use Class::Tiny {
        name => undef,
        value => undef,
        pre_code_override => undef,
        post_code_override => undef,
    };

    sub pre_code  {
        my $self = shift;
        return $self->pre_code_override if defined $self->pre_code_override;
        return '';
    }

    sub post_code  {
        my $self = shift;
        return $self->post_code_override if defined $self->post_code_override;
        return '';
    }

    sub get_var {
        my ($self, $name, $type) = @_;
        return if $type && !$self->isa($type);  # empty list
        return if $name ne $self->{name};       # empty list
        return $self->{value};                  # scalar
    }

    sub quote_values_as_perl {
        my $self = shift;
        my @perl_values = map {
            my $val = Data::Dumper->new([$_])->Terse(1)->Purity(1)->Useqq(1)->Sortkeys(1)->Dump;
            chomp $val;
            $val;
        } @_;
        Carp::confess("quote_values_as_perl called with multiple items in scalar context (@perl_values)")
            if @perl_values > 1 && !wantarray;
        return $perl_values[0] unless wantarray;
        return @perl_values;
    }

} # Context::BaseItem


{
    package Context::EnvVar;
    use strict;
    use parent -norequire, 'Context::BaseItem';

    # subclass representing a named environment variable

    sub pre_code {
        my $self = shift;
        return $self->pre_code_override if defined $self->pre_code_override;
        my $perl_value = $self->quote_values_as_perl($self->{value});
        return sprintf '$ENV{%s} = %s;%s', $self->{name}, $perl_value, "\n";
    }

    sub post_code {
        my $self = shift;
        return $self->post_code_override if defined $self->post_code_override;
        return sprintf 'END { delete $ENV{%s} }%s', $self->{name}, "\n"; # for VMS
    }

} # Context::EnvVar


{
    package Context::OurVar;
    use strict;
    use parent -norequire, 'Context::BaseItem';

    # subclass representing a named 'our' variable

    sub pre_code {
        my $self = shift;
        return $self->pre_code_override if defined $self->pre_code_override;
        my $perl_value = $self->quote_values_as_perl($self->{value});
        return sprintf 'our $%s = %s;%s', $self->{name}, $perl_value, "\n";
    }

} # Context::OurVar


{
    package Context::ModuleUse;
    use strict;
    use parent -norequire, 'Context::BaseItem';

    # subclass representing 'use $name (@$value)'

    sub pre_code {
        my $self = shift;
        return $self->pre_code_override if defined $self->pre_code_override;
        my @imports = $self->quote_values_as_perl(@{$self->{value}});
        return sprintf 'use %s (%s);%s', $self->{name}, join(", ", @imports), "\n";
    }

} # Context::ModuleUse

{
    package Context::MetaInfo;
    use strict;
    use parent -norequire, 'Context::BaseItem';

    # subclass that doesn't generate any code (pre_code or post_code);
    # It's just used to convey information between plugins

} # Context::ModuleUse

1;
