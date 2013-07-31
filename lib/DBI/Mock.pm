package DBI::Mock;

use strict;
use warnings;

use Carp qw(carp confess);

sub _set_isa
{
    my ( $classes, $topclass ) = @_;
    foreach my $suffix ( '::dr', '::db', '::st' )
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

    my $c = ref $ref;

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

    return;
}

my %default_attrs = (
                      Warn                => 1,
                      Active              => 1,
                      Executed            => 0,         # set on execute ...
                      Kids                => 0,
                      ActiveKids          => 0,
                      CachedKids          => 0,
                      Type                => "db",
                      ChildHandles        => undef,     # XXX improve to fake :/
                      CompatMode          => 0,
                      InactiveDestroy     => 0,
                      AutoInactiveDestroy => 0,
                      PrintWarn           => $^W,
                      PrintError          => 1,
                      RaiseError          => 0,
                      HandleError         => undef,     # XXX no default specified
                      HandleSetErr        => undef,     # XXX no default specified
                      ErrCount            => 0,
                      ShowErrorStatement  => undef,     # XXX no default specified
                      TraceLevel          => 0,         # XXX no default specified
                      FetchHashKeyName    => "NAME",    # XXX no default specified
                      ChopBlanks          => undef,     # XXX no default specified
                      LongReadLen         => 0,
                      LongTruncOk         => 0,
                      TaintIn             => 0,
                      TaintOut            => 0,
                      Taint               => 0,
                      Profile             => undef,     # XXX no default specified
                      ReadOnly            => 1,
                      Callbacks           => undef,
                    );

sub _make_handle
{
    my ( $ref, $name ) = @_;
    my $h = bless( { %default_attrs, %$ref }, $name );
    exists $h->{attrs}
      and exists $h->{attrs}->{RootClass}
      and _make_root_class( $h, delete $h->{attrs}->{RootClass} );
    return $h;
}

my %drivers;

sub _get_drv
{
    my ( $self, $dsn, $attrs ) = @_;
    my $class = "DBI::dr";    # XXX maybe extract it from DSN? ...
    defined $drivers{$class} or $drivers{$class} = _make_handle( $attrs, $class );
    return $drivers{$class};
}

sub connect
{
    my ( $self, $dsn, $user, $pass, $attrs ) = @_;
    my $drh = $self->_get_drv( $dsn, $attrs );
    $drh->connect( $dsn, $user, $pass, $attrs );
}

sub installed_drivers { %drivers; }
sub available_drivers { 'NullP' }

our $stderr = 1;
our $err;
our $errstr;

sub err    { $err }
sub errstr { $errstr }

sub set_err
{
    my ( $ref, $_err, $_errstr ) = @_;
    $err    = $_err;
    $errstr = $_errstr;
    return;
}

{
    package    #
      DBI::Mock::dr;

    our @ISA;

    my %default_db_attrs = (
                             AutoCommit   => 1,
                             Driver       => undef,    # set to the driver itself ...
                             Name         => "",
                             Statement    => "",
                             RowCacheSize => 0,
                             Username     => "",
                           );

    sub connect
    {
        my ( $drh, $dbname, $user, $auth, $attrs ) = @_;
        return
          DBI::Mock::_make_handle(
                                   {
                                      %default_db_attrs,
                                      %$attrs,
                                      (
                                         defined $drh->{RootClass}
                                         ? ( RootClass => $drh->{RootClass} )
                                         : ()
                                      )
                                   },
                                   "DBI::db"
                                 );
    }

    our $err;
    our $errstr;

    sub err    { $err }
    sub errstr { $errstr }

    sub set_err
    {
        my ( $ref, $_err, $_errstr ) = @_;
        $err    = $_err;
        $errstr = $_errstr;
        return;
    }

    sub FETCH
    {
        my ( $dbh, $attr ) = @_;
        return $dbh->{$attr};
    }

    sub STORE
    {
        my ( $dbh, $attr, $val ) = @_;
        return $dbh->{$attr} = $val;
    }
}
{
    package    #
      DBI::Mock::db;

    our @ISA;

    my %default_st_attrs = (
                             NUM_OF_FIELDS => undef,
                             NUM_OF_PARAMS => undef,
                             NAME          => undef,
                             NAME_lc       => undef,
                             NAME_uc       => undef,
                             NAME_hash     => undef,
                             NAME_lc_hash  => undef,
                             NAME_uc_hash  => undef,
                             TYPE          => undef,
                             PRECISION     => undef,
                             SCALE         => undef,
                             NULLABLE      => undef,
                             CursorName    => undef,
                             Database      => undef,
                             Statement     => undef,
                             ParamValues   => undef,
                             ParamTypes    => undef,
                             ParamArrays   => undef,
                             RowsInCache   => undef,
                           );

    sub _valid_stmt
    {
        1;
    }

    sub disconnect
    {
        $_[0]->STORE( Active => 0 );
	return 1;
    }

    sub prepare
    {
        my ( $dbh, $stmt, $attrs ) = @_;
        _valid_stmt( $stmt, $attrs ) or return;    # error already set by _valid_stmt
	defined $attrs or $attrs = {};
	ref $attrs eq "HASH" or $attrs = {};
        return
          DBI::Mock::_make_handle(
                                   {
                                      %default_st_attrs,
                                      %$attrs,
                                      Statement => $stmt,
                                      (
                                         defined $dbh->{RootClass}
                                         ? ( RootClass => $dbh->{RootClass} )
                                         : ()
                                      )
                                   },
                                   "DBI::st"
                                 );
    }

    sub do
    {
        my ( $dbh, $stmt, $attr, @bind_values ) = @_;
        my $sth = $dbh->prepare( $stmt, $attr ) or return;
        my $rows = $sth->execute(@bind_values);
        $rows or return $dbh->set_err( $DBI::stderr, $sth->errstr );
        $rows;
    }

    our $err;
    our $errstr;

    sub err    { $err }
    sub errstr { $errstr }

    sub set_err
    {
        my ( $ref, $_err, $_errstr ) = @_;
        $err    = $_err;
        $errstr = $_errstr;
        return;
    }

    sub FETCH
    {
        my ( $dbh, $attr ) = @_;
        return $dbh->{$attr};
    }

    sub STORE
    {
        my ( $dbh, $attr, $val ) = @_;
        return $dbh->{$attr} = $val;
    }
}

{
    package    #
      DBI::Mock::st;

    our @ISA;

    my %default_attrs = ();

    sub execute
    {
	"0E0"
    }

    sub fetchrow_arrayref
    {
    }

    our $err;
    our $errstr;

    sub err    { $err }
    sub errstr { $errstr }

    sub set_err
    {
        my ( $ref, $_err, $_errstr ) = @_;
        $err    = $_err;
        $errstr = $_errstr;
        return;
    }

    sub FETCH
    {
        my ( $dbh, $attr ) = @_;
        return $dbh->{$attr};
    }

    sub STORE
    {
        my ( $dbh, $attr, $val ) = @_;
        return $dbh->{$attr} = $val;
    }
}

sub _inject_mock_dbi
{
    eval qq{
	package #
	    DBI;

	our \@ISA = qw(DBI::Mock);

	our \$VERSION = "1.625";

	package #
	    DBI::dr;

	our \@ISA = qw(DBI::Mock::dr);

	package #
	    DBI::db;

	our \@ISA = qw(DBI::Mock::db);

	package #
	    DBI::st;

	our \@ISA = qw(DBI::Mock::st);

	1;
    };
    $@ and die $@;
    $INC{'DBI.pm'} = 'mocked';
}

my $_have_dbi;

sub _miss_dbi
{
    defined $_have_dbi and return !$_have_dbi;
    $_have_dbi = 0;
    eval qq{
	require DBI;
	\$_have_dbi = 1;
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

1;

=head1 NAME

DBI::Mock - mock a DBI if we can't find the real one

=head1 SYNOPSIS

  use DBI::Mock;

  my $dbh = DBI::Mock->connect($data_source, $user, $pass, \%attr) or die $DBI::Mock::errstr;
  my $sth = $dbh->prepare();
  $sth->execute();

  ... copy some from DBI SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

This module is a team-effort. The current team members are

  H.Merijn Brand   (Tux)
  Jens Rehsack     (Sno)
  Peter Rabbitson  (ribasushi)
  Joakim TE<0x00f8>rmoen   (trmjoa)

=head1 COPYRIGHT AND LICENSE

Copyright (C)2013 - The DBI development team

You may distribute this module under the terms of either the GNU
General Public License or the Artistic License, as specified in
the Perl README file.

=cut
