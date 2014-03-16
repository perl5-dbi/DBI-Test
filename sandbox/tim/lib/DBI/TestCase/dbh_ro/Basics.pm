package DBI::TestCase::dbh_ro::Basics;

use Test::Most;
use DBI::Test::CheckUtil;
use base 'DBI::Test::CaseBase';


sub get_subtest_method_names {
    return qw(test_dbh_destroy);
}


sub test_dbh_destroy {
    my ($test) = @_;

    my $drh = $test->dbh->{Driver};
    drh_ok $drh;
    h_no_err $drh;

    my $dbh_err;
    SCOPE: {
        my $tmp_dbh = $test->dbi_connect_hook->($test, { PrintError => 0 });
        is $tmp_dbh->{Driver}, $drh, 'new dbh has same driver';

        $tmp_dbh->do("invalid_statement");
        h_has_err $tmp_dbh, 'should have error after invalid statement';
        $dbh_err = $tmp_dbh->err;

        h_no_err $drh, 'drh err should not be set when dbh err is set';
    }

    # this is the key test
    is $drh->err, $dbh_err, 'when a dbh is destroyed the parent drh err should match the dbh err';

}


1;
