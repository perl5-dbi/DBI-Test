package Data::Tumbler;

use strict;

use Storable qw(dclone);

use parent 'Exporter';

our @EXPORT = 'tumbler';


# tumbler(
#   $providers,  - array of code refs returning key-value pairs of variants
#   $consumer,   - code ref called for at the leaves of the produced tree of variants
#   $path,       - array of current variant names, one for each level of provider
#   $context,    - accumulated current variant values
#   $payload,    - opaque data passed to $providers (which may edit it) and to $consumer
# )

sub tumbler {
    my ($providers, $consumer, $path, $context, $payload) = @_;

    if (not @$providers) { # no more providers in this context
        $consumer->($path, $context, $payload);
        return;
    }

    # clone the $payload so the provider can alter it for the consumer
    # at and below this point in the tree of variants
    $payload = dclone($payload);

    my ($current_provider, @remaining_providers) = @$providers;

    # call the current provider to supply the variants for this context
    # returns empty if the consumer shouldn't be called in the current context
    # returns a single (possibly nil/empty/dummy) variant if there are
    # no actual variations needed.
    my %variants = $current_provider->($path, $context, $payload);

    # for each variant in turn, call the next level of provider
    # with the name and value of the variant appended to the
    # path and context.

    for my $name (sort keys %variants) {

        tumbler(
            \@remaining_providers,
            $consumer,
            [ @$path,  $name ],
            $context->new($context, $variants{$name}),
            $payload,
        );
    }

    return;
}

1;
