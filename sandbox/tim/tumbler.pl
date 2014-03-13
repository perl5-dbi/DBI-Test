#!/bin/env perl

use strict;
use Data::Dumper;
use Getopt::Long;

use lib 'lib';

use Context;
use WriteTestVariants;

$| = 1;
my $output_dir = "out";

rename $output_dir, $output_dir.'-'.time
    if -d $output_dir;

my $test_writer = WriteTestVariants->new(
    test_case_default_namespace => 'DBI::TestCase',
);

$test_writer->write_test_variants(
    $output_dir,
    [
        "DBI::Test::VariantDBI",
        "DBI::Test::VariantDriver",
        "DBI::Test::VariantDBD",
    ]
);

exit 0;
