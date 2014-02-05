package Fixture;

use strict;
use warnings;
use Carp qw(croak);

use Class::Tiny {
    statement => sub {
        croak "Fixture doesn't define a statement"
    },
    demolish => sub { sub {} },
};


sub DEMOLISH {
    my $self = shift;
    $self->demolish->($self);
}

1;
