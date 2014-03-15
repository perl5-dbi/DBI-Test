package Test::WriteVariants;

use strict;
use warnings;
use autodie;

use File::Find;
use File::Path;
use File::Basename;
use Module::Pluggable::Object;
use Carp qw(croak);

use lib 'lib';

use Context;
use Data::Tumbler;


use Class::Tiny {

    initial_tumble_path => sub {
        return []
    },
    initial_tumble_context => sub {
        use Context;
        return Context->new
    },
    add_context => sub {
        return sub {
            my ($context, $item) = @_;
            return $context->new($context, $item);
        }
    },

    # If the output directory already exists when tumble() is called it'll
    # throw an exception (and warn if it wasn't created during the run).
    # Setting allow_dir_overwrite true disables this safety check.
    allow_dir_overwrite => 0,

    # If the test file that's about to be written already exists
    # then write_test_file() will throw an exception.
    # Setting allow_file_overwrite true disables this safety check.
    allow_file_overwrite => 0,
};


sub write_test_variants {
    my ($self, %args) = @_;

    my $search_path = delete $args{search_path}
        or croak "search_path not specified";
    my $search_dirs = delete $args{search_dirs};
    my $variant_providers = delete $args{variant_providers}
        or croak "variant_providers not specified";
    my $output_dir = delete $args{output_dir}
        or croak "output_dir not specified";

    croak "write_test_variants: $output_dir already exists"
        if -d $output_dir and not $self->allow_dir_overwrite;

    # if a provider is a namespace name instead of a code ref
    # then replace it with a code ref that uses Module::Pluggable
    # to load and run the provider classes in that namespace
    my @providers = @$variant_providers;
    for my $provider (@providers) {
        next if ref $provider eq 'CODE';

        my @test_variant_modules = Module::Pluggable::Object->new(
            require => 1,
            on_require_error     => sub { croak "@_" },
            on_instantiate_error => sub { croak "@_" },
            search_path => [ $provider ],
        )->plugins;
        @test_variant_modules = sort @test_variant_modules;

        warn sprintf "Variant providers in %s: %s\n", $provider, join(", ", map {
            (my $n=$_) =~ s/^${provider}:://; $n
        } @test_variant_modules);

        $provider = sub {
            my ($path, $context, $tests) = @_;

            my %variants;
            # loop over several methods as a basic way of letting plugins
            # hook in either early or late if they need to
            for my $method (qw(provider_initial provider provider_final)) {
                for my $test_variant_module (@test_variant_modules) {
                    next unless $test_variant_module->can($method);
                    #warn "$test_variant_module $method...\n";
                    $test_variant_module->$method($path, $context, $tests, \%variants);
                    #warn "$test_variant_module $method: @{[ keys %variants ]}\n";
                }
            }

            return %variants;
        };
    }

    my $input_tests = $self->get_input_tests({
        search_dirs => $search_dirs,
        search_path => $search_path,
    });

    my $tumbler = Data::Tumbler->new(
        consumer => sub {
            my ($path, $context, $payload) = @_;
            # payload is a clone of input_tests possibly modified by providers
            $self->write_test_file($path, $context, $payload, $output_dir);
        },
        add_context => $self->add_context,
    );

    $tumbler->tumble(
        \@providers,
        $self->initial_tumble_path,
        $self->initial_tumble_context,
        $input_tests, # payload
    );

    warn "No tests written to $output_dir!\n"
        if not -d $output_dir and not $self->allow_dir_overwrite;

    return;
}



# ------


sub get_input_tests {
    my ($self, $search_opts) = @_;

    my $namespaces = $search_opts->{search_path}
        or croak "search_path not specified";
    my $namespaces_regex = join "|", map { quotemeta($_) } @$namespaces;
    my $namespaces_qr    = qr/^($namespaces_regex)::/;

    # XXX also find .t files?

    my @test_case_modules = Module::Pluggable::Object->new(
        require => 0,
        %$search_opts,
    )->plugins;

    my %input_tests;
    for my $module_name (@test_case_modules) {

        # map module name, without the namespace prefix, to a dir path
        my $test_name = $module_name;
        $test_name =~ s/$namespaces_qr//;
        $test_name =~ s{[^\w:]+}{_}g;
        $test_name =~ s{::}{/}g;

        die "Test name $test_name already seen ($module_name)"
            if $input_tests{ $test_name };

        $input_tests{ $test_name } = {
            module => $module_name,
        };
    }

    return \%input_tests;
}



sub write_test_file {
    my ($self, $path, $context, $input_tests, $output_dir) = @_;

    my $base_dir_path = join "/", $output_dir, @$path;

    # note that $testname can include a subdirectory path
    for my $testname (sort keys %$input_tests) {
        my $testinfo = $input_tests->{$testname};

        $testname .= ".t" unless $testname =~ m/\.t$/;
        my $full_path = "$base_dir_path/$testname";

        if (-e $full_path) {
            croak "$full_path already exists!\n"
                unless $self->allow_file_overwrite;
        }

        warn "Writing $full_path\n";

        my $test_script = $self->get_test_file_body($context, $testinfo);

        my $full_dir_path = dirname($full_path);
        mkpath($full_dir_path, 0)
            unless -d $full_dir_path;

        open my $fh, ">", $full_path;
        print $fh $test_script;
        close $fh;
    }

    return;
}


sub get_test_file_body {
    my ($self, $context, $testinfo) = @_;

    my $pre  = $context->pre_code;
    my $post = $context->post_code;

    my @body;
    push @body, qq{#!perl\n};
    push @body, qq{use lib "lib";\n}; # XXX remove

    push @body, $pre;

    push @body, "require '$testinfo->{require}';\n"
        if $testinfo->{require};

    if (my $module = $testinfo->{module}) {
        push @body, "use lib '$testinfo->{lib}';\n"
            if $testinfo->{lib};
        push @body, "require $module;\n";
        push @body, "$module->run_tests;\n";
    }

    push @body, "$testinfo->{code}\n"
        if $testinfo->{code};

    push @body, $post;

    return join "", @body;
}



1;
