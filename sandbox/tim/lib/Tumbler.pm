package Tumbler;

use strict;

use Storable qw(dclone);

use parent 'Exporter';

our @EXPORT = 'tumbler';


# tumbler(
#   $providers,  - array of code refs returning key-value pairs of variants
#   $leaf,       - opaque data passed to $providers (which may edit it) and to $consumer
#   $consumer,   - code ref called for each path of variants
#   $path,       - array of current variant names, one for each level of provider
#   $context     - array of current variant values, one for each level of provider
# )

sub tumbler {                              # this code is generic
    my ($providers, $leaf, $consumer, $path, $context) = @_;

    if (not @$providers) { # no more providers in this context
        $consumer->($path, $context, $leaf);
        return $leaf;
    }

    my ($current_provider, @providers) = @$providers;

    # clone the $leaf so the provider can alter it for the consumer
    # at and below this point in the tree of variants
    $leaf = dclone($leaf);

    # call the current provider to supply the variants
    # returns empty if all tests in the current context should be skipped
    # returns a single (possibly nil/empty/dummy) variant if there are
    # no actual variations needed.
    my %variants = $current_provider->($context, $leaf);

    # for each variant in turn, call the next level of provider
    # with the name and value of the variant appended to the
    # path and context.

    for my $name (sort keys %variants) {

        tumbler(
            \@providers, $leaf, $consumer,
            [ @$path,   $name            ],
            $context->new($context, $variants{$name}),
        );
    }

    return;
}

1;
