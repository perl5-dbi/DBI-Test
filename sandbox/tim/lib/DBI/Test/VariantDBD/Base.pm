package DBI::Test::VariantDBD::Base;

use strict;

use DBI::Test::VariantUtil qw(add_variants warn_once);


sub provider_initial {
    my ($self, $path, $context, $tests, $variants) = @_;

    # return variant settings to be tested for the current DSN

    add_variants($variants, {
        # we call this 'Plain' to distinguish it from the similar 'Default'
        # used by the DBI variant provider
        Plain => $context->new(),
    });

    return;
}

1;
