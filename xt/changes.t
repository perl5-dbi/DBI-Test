#!perl

use strict;
use warnings;

use Test::More;
use Test::CPAN::Changes;

changes_file_ok("ChangeLog");

done_testing()
