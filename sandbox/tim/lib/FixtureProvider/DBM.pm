package FixtureProvider::DBM;

use Moo;

extends 'FixtureProvider::GenericBase_SQL';

use DBI::Test::Fixture;


sub get_ro_stmt_select_1r2c_si {
    return shift->get_ro_stmt_select_1r2c_si_kV(@_);
}

sub get_ro_stmt_select_1r2c_si_kV {
    my $self = shift;

    # XXX table name conventions and table management?

    my $table_name = $self->get_dbit_temp_name("select_1r2c_si");

    my $dbh = $self->dbh;
    $dbh->do("create table $table_name (k text, V integer)");
    $dbh->do("insert into $table_name values ('foo', 42)");

    return DBI::Test::Fixture->new(
        statement => "select k, V from $table_name",
        demolish => sub {
            $self->dbh->do("drop table $table_name");
        },
    );
}


1;
