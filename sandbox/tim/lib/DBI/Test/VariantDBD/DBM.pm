package DBI::Test::VariantDBD::DBM;

use strict;

use DBI::Test::VariantUtil qw(add_variants warn_once);


sub provider {
    my ($self, $path, $context, $tests, $variants) = @_;
    # return variant settings to be tested for the current DBI_DRIVER

    return unless $context->get_env_var('DBI_DRIVER') eq 'DBM';

    my $tdb_handle = $context->get_meta_info('tdb_handle')
        or Carp::confess("panic: no tdb_handle");

    my @mldbm_types = ("");
    if ( eval { require 'MLDBM.pm' } ) {
        push @mldbm_types, qw(Data::Dumper Storable); # in CORE
        push @mldbm_types, 'FreezeThaw' if eval { require 'FreezeThaw.pm' };
        push @mldbm_types, 'YAML' if eval { require MLDBM::Serializer::YAML; };
        push @mldbm_types, 'JSON' if eval { require MLDBM::Serializer::JSON; };
    }

    my @dbm_types = grep { eval { local $^W; require "$_.pm" } }
        qw(SDBM_File GDBM_File DB_File BerkeleyDB NDBM_File ODBM_File);

    my %settings;
    for my $mldbm_type (@mldbm_types) {
        for my $dbm_type (@dbm_types) {

            my $tag = join("-", grep { $_ } $mldbm_type, $dbm_type);
            $tag =~ s/:+/_/g;

            # to pass the mldbm_type and dbm_type we use the DBI_DSN env var
            # because the DBD portion is empty the DBI still uses DBI_DRIVER env var
            # XXX really this ought to parse tdb_handle->dsn and append the
            # settings to it so as to preserve any settings in the Test::Database config.
            my $DBI_DSN = "dbi::mldbm_type=$mldbm_type,dbm_type=$dbm_type";
            $settings{$tag} = Context->new_env_var(DBI_DSN => $DBI_DSN);
        }
    }
    add_variants($variants, \%settings);

    # Example of adding a test, in a subdir, for a single driver.
    # Because $tests is cloned in the tumbler this extra item doesn't
    # affect other contexts (but does affect all variants in this context).
    $tests->{'plugin/ExampleExtraTests.t'} = { lib => 'plug', module => 'DBM::ExampleExtraTests' };

    return;
}

1;
