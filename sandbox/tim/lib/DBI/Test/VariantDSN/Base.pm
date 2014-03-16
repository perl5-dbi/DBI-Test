package DBI::Test::VariantDSN::Base;

use strict;

use Test::Database;
use DBI::Test::VariantUtil qw(add_variants warn_once);


sub provider_initial {
    my ($self, $path, $context, $tests, $variants) = @_;

    # return variant for available Test::Database handle

    my $driver = $context->get_env_var('DBI_DRIVER');

    my @tdb_handles = Test::Database->handles({ dbd => $driver })
        or die("panic: no Test::Database handles for $driver - should not get here");

    my $seqn = 0;
    for my $tdb_handle (@tdb_handles) {

        # XXX would be nice to be able to get a short 'name' for a config
        # from the Test::Database handle to use here instead of a number
        my $variant_name = ++$seqn;

        my %settings;
        $settings{$variant_name} = $context->new(
            $context->new_env_var(DBI_DSN  => $tdb_handle->dsn),
            $context->new_env_var(DBI_USER => $tdb_handle->username),
            $context->new_env_var(DBI_PASS => $tdb_handle->password),
            $context->new_meta_info(tdb_handle => $tdb_handle),
        );

        add_variants($variants, \%settings);
    }

    return;
}

1;
