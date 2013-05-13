package DBI::Test::Case::connect;

use Test::More;

our @DB_CREDS = ('dbi:SQLite:dbname=:memory:', undef, undef, { AutoCommit => 0});
my %SQLS = (
  'SELECT' => 'SELECT 1+1',
  'INSERT' => undef
);

{
  my $dbh = DBI->connect( @DB_CREDS );
  isa_ok($dbh, 'DBI::db');
  
  #Active should be true when you are connected
  #disconnect set Active to false
  ok($dbh->{Active}, "dbh is active");
}


{ #Testing that the connect attributes are correctly set  
  SKIP:{
    skip "No attributes provided", 1 if( !defined $DB_CREDS[3] || ref($DB_CREDS[3]) ne 'HASH'  );
    
    my $dbh = DBI->connect( @DB_CREDS );
    isa_ok($dbh, 'DBI::db');
    
    #Check the $dbh->{Attribute} and $dbh->FETCH('Attribute') interface
    foreach my $attr ( keys %{ $DB_CREDS[3] }){
      cmp_ok($dbh->{$attr}, '==', $DB_CREDS[3]->{$attr}, $attr . ' == ' . $DB_CREDS[3]->{$attr});
      cmp_ok($dbh->FETCH($attr), '==', $DB_CREDS[3]->{$attr}, $attr . ' == ' . $DB_CREDS[3]->{$attr});
    }
  }
}

{ #Check some default values

  my $dbh = DBI->connect( @DB_CREDS[0..2], {} );
  isa_ok($dbh, 'DBI::db');
  
  for( qw(AutoCommit PrintError) ){
    cmp_ok($dbh->{$_}, '==', 1, $_ . ' == 1');
    cmp_ok($dbh->FETCH($_), '==', 1, $_ . ' == 1');
  }

  
  TODO : {
    #Seems like $^W doesnt honor the use warnings pragma.. Is PrintWarn affected by the pragma, or only the -w cmd flag?
    local $TODO = "PrintWarn should default to true if warnings is enabled. How to check?";
    diag '$^W= ' . $^W ."\n";
    cmp_ok( $dbh->{PrintWarn}, '==',  ( ($^W) ? 1 : 0 ), 'PrintWarn == ' . ( ($^W) ? 1 : 0 ));
  }
}

{ #Negative test
  
  #Use a fake dsn that does not exists
  #TODO : Using a invalid dsn does not work. Drivers like SQLite etc will just create a file with that name
  #It isnt so simple we will have to use a DBD that is available. Or do we do them all?
  TODO : {
    local $TODO = "How to make the connect fail. Just using a wrong dsn doesnt seem to cut it";
    
    #TODO, make this more portable
    my $dsn = $DB_CREDS[0];
    #$dsn =~ s/(dbi:[A-Za-z_\-0-9]+::).+/$1/; $dsn .= "invalid_db";
    
    #PrintError is on by default, so we should check that we can intercept a warning
    my $warnings = 0;
    
    #TODO : improve this
    local $SIG{__WARN__} = sub {
      $warnings++;
    };
    
    my @a = ($dsn, @DB_CREDS[1..2], {});
    ok(!DBI->connect($dsn, @DB_CREDS[1..2], {}), "Connection failure");
    
    cmp_ok($warnings, '>', 0, "warning displayed");
    
    ok($DBI::err, '$DBI::err defined');
    ok($DBI::errstr, '$DBI::errstr defined');
  }
}

done_testing();
