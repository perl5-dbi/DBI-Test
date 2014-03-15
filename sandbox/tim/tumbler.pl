#!/bin/env perl

use strict;
use Data::Dumper;
use Getopt::Long;

use lib 'lib';

use Test::WriteVariants;

$| = 1;
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

my $test_writer = Test::WriteVariants->new();

$test_writer->write_test_variants(
    search_path => [
        'DBI::TestCase'
    ],
    variant_providers => [
        "DBI::Test::VariantDBI",
        "DBI::Test::VariantDriver",
        "DBI::Test::VariantDBD",
    ],
    output_dir => $output_dir,
);

exit 0;
