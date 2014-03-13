package DBI::Test::VariantUtil;

use strict;
use Carp;
use Exporter;
use base 'Exporter';

our @EXPORT_OK = qw(
    add_variants
    duplicate_variants_with_extra_settings
    warn_once
);


sub add_variants {
    my ($dst, $src, $prefix, $suffix) = @_;
    for my $src_key (keys %$src) {
        my $dst_key = $src_key;
        $dst_key = "$prefix-$dst_key" if defined $prefix;
        $dst_key = "$dst_key-$suffix" if defined $suffix;
        croak "Test variant setting key '$dst_key' already exists"
            if exists $dst->{$dst_key};
        $dst->{$dst_key} = $src->{$src_key};
    }
    return;
}


sub duplicate_variants_with_extra_settings {
    my ($dst, $extras) = @_;

    for my $dst_name (keys %$dst) {

        my %extra_settings = map {
            $_ => Context->new( $dst->{$dst_name}, $extras->{$_} )
        } keys %$extras;

        add_variants($dst, \%extra_settings, $dst_name, undef);
    }

    return;
}


sub warn_once {
    my ($msg) = @_;
    warn $msg unless our $warn_once_seen_msg->{$msg}++;
}


1;
