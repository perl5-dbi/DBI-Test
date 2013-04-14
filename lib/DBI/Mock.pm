package DBI::Mock;

=head1 NAME

DBI::Mock - mock a DBI if we can't find the real one

=head1 SYNOPSIS

  use DBI::Mock;

  my $dbh = DBI::Mock->connect($data_source, $user, $pass, \%attr) or die $DBI::Mock::errstr;
  my $sth = $dbh->prepare();
  $sth->execute();

  ... copy some from DBI SYNOPSIS

=cut

use strict;
use warnings;

use Carp qw(carp confess);

sub _set_isa
{
    my ( $classes, $topclass ) = @_;
    foreach my $suffix ( '::db', '::st' )
    {
        my $previous = $topclass || 'DBI';    # trees are rooted here
        foreach my $class (@$classes)
        {
            my $base_class    = $previous . $suffix;
            my $sub_class     = $class . $suffix;
            my $sub_class_isa = "${sub_class}::ISA";
            no strict 'refs';
            @$sub_class_isa or @$sub_class_isa = ($base_class);
            $previous = $class;
        }
    }
}

sub _make_root_class
{
    my ( $ref, $root ) = @_;
    $root or return;

    $c = ref $ref;

    no strict 'refs';
    eval qq{
	package $c;
	require $root;
    };
    $@ and return;

    unless ( @{"$root\::db::ISA"} && @{"$root\::st::ISA"} )
    {
        carp("DBI subclasses '$root\::db' and ::st are not setup, RootClass ignored");
    }
    else
    {
        $ref->{RootClass} = $root;
        _set_isa( [$root], 'DBI::Mock' );
        bless( $ref, $root );
    }

}

sub _make_handle
{
    my ( $ref, $name ) = @_;
    my $h = bless( $ref, $name );
    exists $h->{attrs}
      and exists $h->{attrs}->{RootClass}
      and _make_root_class( $h, delete $h->{attrs}->{RootClass} );
    return $h;
}

sub connect
{
    my ( $self, $dsn, $user, $pass, $attrs ) = @_;
    my $dbh = {
                data_source => $dsn,
                user        => $user,
                passw       => $pass,
                attrs       => $attrs
              };
    return _make_handle( $dbh, "DBI::Mock::db" );
}

our $stderr = 1;
our $err;
our $errstr;

sub err { $err }
sub errstr { $errstr }

sub set_err
{
    my ($ref, $_err, $_errstr) = @_;
    $err = $_err;
    $errstr = $_errstr;;
    return;
}

{
    package    #
      DBI::Mock::db;

    our @ISA;

    sub prepare
    {
	my ($dbh, $stmt, $attrs) = @_;
	_valid_stmt($stmt, $attrs) or return; # error already set by _valid_stmt
	$dbh->{RootClass} and $attrs->{RootClass} = $dbh->{RootClass};
	my $sth = {stmt => $stmt, attrs => $attrs};
	return _make_handle($attrs, "DBI::Mock::st");
    }

    sub do
    {
	my ($dbh, $stmt, $attr, @bind_values) = @_;
	my $sth = $dbh->prepare($stmt, $attr) or return;
	my $rows = $sth->execute(@bind_values);
	$rows or return $dbh->set_err($DBI::stderr, $sth->errstr);
	$rows;
    }

    our $err;
    our $errstr;

    sub err { $err }
    sub errstr { $errstr }

    sub set_err
    {
	my ($ref, $_err, $_errstr) = @_;
	$err = $_err;
	$errstr = $_errstr;;
	return;
    }
}

{
    package    #
      DBI::Mock::st;

    our @ISA;

    sub execute
    {
    }

    sub fetchrow_arrayref
    {
    }

    our $err;
    our $errstr;

    sub err { $err }
    sub errstr { $errstr }

    sub set_err
    {
	my ($ref, $_err, $_errstr) = @_;
	$err = $_err;
	$errstr = $_errstr;;
	return;
    }
}

sub _inject_mock_dbi
{
    eval qq{
	package DBI;

	use parent qw(DBI::Mock);

	our VERSION = "1.625";
    };
    $INC{'DBI.pm'} = 'mocked';
}

my $_have_dbi;

sub _miss_dbi
{
    defined $_have_dbi and return !$_have_dbi;
    $_have_dbi = 0;
    eval qq{
	require DBI;
	$_have_dbi = 1;
    };
    return !$_have_dbi;
}

BEGIN
{
    if ( $ENV{DBI_MOCK} || _miss_dbi() )
    {
        _inject_mock_dbi();
    }
}

=head1 AUTHOR AND COPYRIGHT

Copyright (c) 2013 by Jens Rehsack: rehsackATcpan.org

All rights reserved.

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut
