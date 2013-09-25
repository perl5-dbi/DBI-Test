# GOAL(s)

# Here is the things we are trying to do

Jens Rehsack (Sno)
------------------

1) reduce effort n managing and maintaining tests between SQL::Statement
   and database emulation drivers in DBI (DBI::DBD::SqlEngine based stuff).

2) want the tests from DBD::CSV (ChopBlanks, ...) shared with SQL::Statement
   and DBD::DBM (reduce Merijns effort)

3) want all 3rd party DBI::DBD::SqlEngine based DBDs tested against
   SQL::Statement and DBI::SQL::Nano (improve quality of Nano and improve
   usability out there)


H.Merijn Brand (Tux)
--------------------

1) Test DBI API from both side - from DBI (inside and while delivering DBI)
   and on DBD side whether the DBD supports the API correctly or not
   (think about ReadOnly, TypeInfo, ...)

2) Increase test coverage over the usage of DBD::CSV (run entire test suite
   against Text::CSV and Text::CSV_XS)

Peter Rabbitson (ribasushi)
---------------------------

1) Write one test when a driver fails stuff in DBIx::Class and (hopefully)
   get it tested in any DBI::Test using DBD.
   ==> improve DBIx::Class user experience by error free DBDs
   ==> reduce support effort because of bugs in DBDs

2) Shared DSN config setup to allow DBDs with difference access methods 
   run all (suitable) tests against all access methods, eg. say one has
   an MS-SQL server for testing:
    [09:24am] riba: DBD::Sybase compiled against ( freetds | the sybase native client |  mje's... thingy forgot the company name )
    [09:25am] riba: DBD::ODBC via ( Freetds | mje's driver | microsoft's recently released linux driver )
    [09:25am] riba: DBD::Freetds (doesn't really compile these days )
