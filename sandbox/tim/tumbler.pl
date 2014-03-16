#!/bin/env perl

use strict;
use Data::Dumper;
use Getopt::Long;

use lib 'lib';

use Test::WriteVariants 0.004;

use YAML::Tiny 1.62; # XXX temp to ensure Test::Database works

$| = 1;
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

my $test_writer = Test::WriteVariants->new();

$test_writer->write_test_variants(
    input_tests => $test_writer->find_input_test_modules(
        search_path => [ 'DBI::TestCase' ],
        test_prefix => '',
    ),
    variant_providers => [
        "DBI::Test::VariantDBI",    # pureperl, gofer etc
        "DBI::Test::VariantDriver", # available drivers
        "DBI::Test::VariantDSN",    # available DSNs for a DBD
        "DBI::Test::VariantDBD",    # variant configs for a DBD+DSN
    ],
    output_dir => $output_dir,
);

exit 0;
