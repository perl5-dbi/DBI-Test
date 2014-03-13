package DBI::Test::VariantDBD::Base;

use strict;

use DBI::Test::VariantUtil qw(add_variants warn_once);


sub provider_initial {
    my ($self, $path, $context, $tests, $variants) = @_;
    # return variant settings to be tested for the current DBI_DRIVER

    my $driver = $context->get_env_var('DBI_DRIVER');

    my $tdb_handle = $context->get_meta_info('tdb_handle')
        or Carp::confess("panic: no tdb_handle");

    my $default_context = Context->new(
        Context->new_env_var(DBI_DSN => $tdb_handle->dsn),
        Context->new_meta_info(tdb_handle => $tdb_handle),
    );

    # add DBI_USER and DBI_PASS into each variant, if defined
    $default_context->push_var(Context->new_env_var(DBI_USER => $tdb_handle->username))
        if defined $tdb_handle->username;
    $default_context->push_var(Context->new_env_var(DBI_PASS => $tdb_handle->password))
        if defined $tdb_handle->password;

    my $driver_variants = {
        Default => $default_context
    };

    add_variants($variants, $driver_variants);

    return;
}

1;
