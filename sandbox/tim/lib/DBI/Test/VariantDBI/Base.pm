package DBI::Test::VariantDBI::Base;

use strict;
use DBI::Test::VariantUtil qw(add_variants duplicate_variants_with_extra_settings);

sub provider {
    my ($self, $path, $context, $tests, $variants) = @_;

    add_variants($variants, {
        Default  => $context->new, # a 'null setting' with default environment
        pureperl => $context->new_env_var(DBI_PUREPERL => 2),
    });
}


package DBI::Test::VariantDBI::Proxies;

use strict;
use DBI::Test::VariantUtil qw(add_variants duplicate_variants_with_extra_settings);

sub provider {
    my ($self, $path, $context, $tests, $variants) = @_;

    my %proxies;
    $proxies{gofer} = $context->new_env_var(DBI_AUTOPROXY => 'dbi:Gofer:transport=null;policy=pedantic');
    $proxies{multi} = $context->new_env_var(DBI_AUTOPROXY => 'dbi:Multi:')
        if eval { require DBD::Multi }; # XXX untested

    duplicate_variants_with_extra_settings($variants, \%proxies);

    return;
}


package DBI::Test::VariantDBI::Threads;

use strict;
use DBI::Test::VariantUtil qw(add_variants duplicate_variants_with_extra_settings);
use Config qw(%Config);

sub provider {
    my ($self, $path, $context, $tests, $variants) = @_;

    # if threads are supported then add a copy of all the existing settings
    # with 'use threads ();' added. This is probably overkill.
    return unless $Config{useithreads};

    duplicate_variants_with_extra_settings($variants, {
        thread => $context->new_module_use(threads => []),
    });

    return;
}

1;
