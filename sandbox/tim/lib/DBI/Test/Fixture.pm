package DBI::Test::Fixture;

use Moo;

use Carp qw(croak);

has statement => (
    is => 'rw',
);

has demolish => (
    is => 'rw',
);


sub DEMOLISH {
    my $self = shift;
    $self->demolish->($self);
}

1;
