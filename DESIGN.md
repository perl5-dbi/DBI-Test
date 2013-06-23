# DESIGN

Currently this is a list of open issues and discussion points...

## DBI::Test as a DBD author's tool

This is the principle use-case for DBI::Test: to provide a common suite of
tests for multiple drivers.

We need to consider how evolution of DBI::Test will affect driver authors.
Specifically, as DBI::Test add new tests it's quite likely that some drivers
will fail that test, but that failure is not a regression for the driver.

So it seems reasonable for DBI::Test to be primarily a developer tool
and not run as a standard part of the drivers' test suite, at least for now.
In other words, DBI::Test would only be run if AUTHOR_TESTING is true.

That also allows us to duck the issue of whether DBD's should list DBI::Test as
a dependency. At least for now.


## DBI::Test as a DBI developer's tool

The goal here would be to test the methods the DBI implements itself and the
services the DBI provides to drivers, and also to test the various drivers
shipped with the DBI.

This is a secondary goal.


## List some minimum and other edge cases we want to handle

Example miniumum: Using the DBM with 

## 


## Should we create .t files at all, and if so, how many?

There's a need to have a separate process for some test cases, like
testing DBI vs DBI::PurePerl. But others, like Gofer (DBI_AUTOPROXY)
don't need a separate process.

Let's keep the generation of test files for now, but keep in mind the
possibility that some 'context combinations' might be handled
dynamically in future, i.e., inside the run_test() subroutine.


## Should test modules execute on load or require a subroutine call?

Execute on load seems like a poor choice to me.
I'd rather see something like a sub run { ... } in each test module.


## How and where should database connections be made?

I think the modules that implement tests should not perform connections.
The $dbh to use should be provided as an argument.


## How and where should test tables be created?

I think that creating the test tables, like connecting,
should be kept out of the main test modules.

So I envisage two kinds of test modules. Low-level ones that are given a $dbh
and run tests using that, and higher-level modules that handle connecting and
test table creation. The needs of each are different.


## Should subtests should be used?

I think subtests would be useful for non-trivial test files.
See subtests in https://metacpan.org/module/Test::More
The run() sub could look something like this:

    our $dbh;
    sub run {
        $dbh = shift;
        subtest '...', \&foo;
        subtest '...', \&bar;
        subtest '...', \&baz;
    }

to invoke a set of tests. Taking that a step further, the run() function could
automatically detect what test functions exist in a package and call each in turn.
It could also call setup and teardown subs that could control fixtures.
Then test modules would look something like this:

    use DBI::Test::RunTestModule qw(run);
    sub test__setup { ... }
    sub test__teardown { ... }
    sub test_foo { ... }
    sub test_bar { ... }
    sub test_baz { ... }

The imported run() could also do things like randomize the execution
order of the test_* subs.


## Is there a need for some kind of 'test context' object?

The low-level test modules should gather as much of the info they need from the
$dbh and $dbh->get_info. If extra information is needed in oder to implement
tests we at least these options:

1. Use a $dbh->{dbi_test_foo} handle attribute (and $dbh->{Driver}{dbi_test_bar})
2. Subclass the DBI and add a new method $dbh->dbi_test_foo(...)
3. Pass an extra argument to the run() function
4. Use a global, managed by a higher-level module

Which of those suits best would become more clear further down the road.

