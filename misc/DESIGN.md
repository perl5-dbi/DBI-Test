# DESIGN

# Here is code POV

The code is currently split into 2 large potions - whereby one thing is shared.

Potion 1: configure stage support
---------------------------------

In this stage, the tests for the incarnations are generated. To do this,
DBI::Test::Conf runs through some steps

  a) find all config plugins and load their configuration setting

	my $finder = Module::Pluggable::Object->new(
						     search_path => ["DBI::Test"],
						     require     => 1,
						     only        => qr/::Conf$/,
						     inner       => 0
						   );
	my @plugs = grep { $_->isa("DBI::Test::Conf") } $finder->plugins();

  b) find all list plugins and load there test cases list

	my $finder = Module::Pluggable::Object->new(
						     search_path => ["DBI::Test"],
						     require     => 1,
						     only        => qr/::List$/,
						     inner       => 0
						   );
	my @plugs = grep { $_->isa("DBI::Test::List") } $finder->plugins();

  c) ask DBI about the available_drivers()

  d) create a n over k matrix for required test configurations

  foreach test case

      i) request test case to kick out unsupported DBD's (filter_drivers)
         ==> DBI::Test::Case provides a filter based on CONTAINED_DBDS

     ii) generate matrix of any supported driver and it's variants (in case
         of requires_extended) using DSN::Provider.

    iii) request test case to identify unsupported driver variants
         (PURE_PERL and XS?)

     iv) generate test file from template and populate it as
         $basedir/namespace/${conf_prefix}_${driver_prefix}_test_case.t

	 Template looks (more or less) like:

	 #!perl

	 %s # begin stub, eg. $ENV{DBI_AUTOPROXY} = 'dbi:Gofer:transport=null;policy=pedantic';

	 %s # end stub, eg. delete $ENV{DBI_AUTOPROXY};

	 use DBI::Mock;
	 use DBI::Test::DSN::Provider;

	 use DBI::Test::Case::${namespace}::${test_case}; # full qualified test case namespace

	 my $test_case_conf = DBI::Test::DSN::Provider->get_dsn_creds($test_case_ns, [$dsn_creds]);
	 $test_case_ns->run_test($test_case_conf);

Potion 2: test stage support
----------------------------

  a) boostrap test case

     Tests populated via template processing (basic built-in engine, no TT2 or
     similar) rely on the DSN::Provider (bad design at the moment, only created
     in a fashion to have no show stopper for basic tests) - it creates the used
     base directory for DBD::DBM tests etc. (DSN::Provider is shared, it is also
     called in d-ii above).

  b) run tests

     Once we have a DSN - we give it to run_tests(). In run_tests, test functions
     from DBI::Test can be used, like connect_ok, prepare_ok etc.
     Those tests not only prove the return value (true|false), the also prove the
     right instantiation ($dbh->blessed && $dbh->isa("DBI::db")).

