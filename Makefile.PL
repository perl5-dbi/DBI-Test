# -*- perl -*-

use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile1(
                MIN_PERL_VERSION => '5.008',
                META_MERGE       => {
                              resources => {
                                  repository => 'https://github.com/perl5-dbi/DBI-Test',
                                  MailingList => 'mailto:dbi-dev@perl.org',
                                  license     => 'http://dev.perl.org/licenses/',
                              },
                              },
                NAME          => 'DBI::Test',
                VERSION_FROM  => 'lib/DBI/Test.pm',
                ABSTRACT_FROM => 'lib/DBI/Test.pm',
                dist          => {
                          'SUFFIX'       => ".gz",
                          'DIST_DEFAULT' => 'manifest tardist',
                          'COMPRESS'     => "gzip -9vf"
                        },
                BUILD_REQUIRES => {
                                    'Test::Simple'  => '0.90',
                                  },
                LICENSE => 'perl',
                AUTHOR  => 'Jens Rehsack <rehsack@cpan.org>',
                test    => { TESTS => 't/*.t xt/*.t' },
              );

sub WriteMakefile1
{    #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params       = @_;
    my $eumm_version = $ExtUtils::MakeMaker::VERSION;
    $eumm_version = eval $eumm_version;
    die "EXTRA_META is deprecated" if ( exists( $params{EXTRA_META} ) );
    die "License not specified"    if ( !exists( $params{LICENSE} ) );
    if ( $params{BUILD_REQUIRES} and ( $eumm_version < 6.5503 ) )
    {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM} = { %{ $params{PREREQ_PM} || {} }, %{ $params{BUILD_REQUIRES} } };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if ( $eumm_version < 6.52 );
    delete $params{MIN_PERL_VERSION}   if ( $eumm_version < 6.48 );
    delete $params{META_MERGE}         if ( $eumm_version < 6.46 );
    delete $params{META_ADD}           if ( $eumm_version < 6.46 );
    delete $params{LICENSE}            if ( $eumm_version < 6.31 );
    delete $params{AUTHOR}             if ( $] < 5.005 );
    delete $params{ABSTRACT_FROM}      if ( $] < 5.005 );
    delete $params{BINARY_LOCATION}    if ( $] < 5.005 );

    WriteMakefile(%params);
}
