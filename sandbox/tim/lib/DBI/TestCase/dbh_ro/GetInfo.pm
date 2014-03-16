package DBI::TestCase::dbh_ro::GetInfo;

# Test $dbh->get_info($info_type) using unambiguous $info_type values
# ie values where ISO and ANSI agree (I'm hoping that covers all the ones we care about)
# Doesn't test DBI::Const::GetInfoType - that can be done elsewhere.
#
# http://msdn.microsoft.com/en-us/library/ms711681(v=vs.85).aspx

use Test::Most;
use DBI::Test::CheckUtil;
use base 'DBI::Test::CaseBase';


use DBI::Const::GetInfoType; # used here only for diagnostics
my %InfoTypeName = reverse %GetInfoType;


sub _get_info_like {
    my ($self, $info_type, $qr) = @_;

    my $info_name = $InfoTypeName{$info_type} || "<$info_type>";

    like $self->dbh->get_info($info_type), $qr, "get_info($info_type ($info_name))";
}


sub test_get_info {
    my $self = shift;
    my $dbh = $self->dbh;

    $TODO = "XXX few drivers support all of these";

    # 17 = SQL_DBMS_NAME
    $self->_get_info_like(17, qr{^\w+}); 

    # 18 = SQL_DBMS_VER
    $self->_get_info_like(18, qr{^\d+\.\d+\.\d+}); # looser than formal spec

    # 29 = SQL_IDENTIFIER_QUOTE_CHAR
    $self->_get_info_like(29, qr{^\W$}); 

    # 41 = SQL_CATALOG_NAME_SEPARATOR formerly SQL_QUALIFIER_NAME_SEPARATOR
    # empty if catalogs are not supported)
    $self->_get_info_like(41, qr{^\W?$}); 

    # 114 = SQL_CATALOG_LOCATION formerly SQL_QUALIFIER_LOCATION
    # 0 if catalogs are not supported
    $self->_get_info_like(114, qr{^\d$}); 

}


sub get_subtest_method_names {
    return qw(test_get_info);
}

1;
