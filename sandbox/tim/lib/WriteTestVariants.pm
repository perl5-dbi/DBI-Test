package WriteTestVariants;

use strict;
use warnings;
use autodie;

use File::Find;
use File::Path;
use File::Basename;
use Carp qw(croak);

use lib 'lib';

use Context;
use Data::Tumbler;

use Class::Tiny {
    initial_path => sub {
        return []
    },
    initial_context => sub {
        use Context;
        return Context->new
    },
    add_context => sub {
        return sub {
            my ($context, $item) = @_;
            return $context->new($context, $item);
        }
    },
};


sub write_test_variants {
    my ($self, $input_dir, $output_dir, $providers) = @_;

    croak "output_test_dir $output_dir already exists"
        if -d $output_dir;

    my $input_tests = $self->get_input_tests($input_dir);

    my $tumbler = Data::Tumbler->new(
        consumer => sub {
            my ($path, $context, $payload) = @_;
            # payload is a clone of input_tests possibly modified by providers
            $self->write_test_file($path, $context, $payload, $output_dir);
        },
        add_context => $self->add_context,
    );

    $tumbler->tumble(
        $providers,
        $self->initial_path,
        $self->initial_context,
        $input_tests, # payload
    );

    die "No tests written to $output_dir!\n"
        unless -d $output_dir;

    return;
}



# ------


sub get_input_tests {
    my ($self, $template_dir) = @_;

    my %input_tests;
    my $wanted = sub {
        return unless m/\.pm$/;

        my $name = $File::Find::name;
        $name =~ s!\Q$template_dir\E/!!;    # remove prefix to just get relative path
        $name =~ s!\.pm$!!;                 # remove the .pm suffix
        (my $module_name = $name) =~ s!/!::!g; # convert to module name

        $input_tests{ $name } = {             # use relative path as key
            lib => $template_dir,
            module => $module_name,
        };
    };
    find($wanted, $template_dir);

    return \%input_tests;
}



sub write_test_file {
    my ($self, $path, $context, $input_tests, $output_dir) = @_;

    my $dirpath = join "/", $output_dir, @$path;

    for my $testname (sort keys %$input_tests) {
        my $testinfo = $input_tests->{$testname};

        $testname .= ".t" unless $testname =~ m/\.t$/;
        warn "Writing $dirpath/$testname\n";

        my $test_script = $self->get_test_file_body($context, $testinfo);

        mkfilepath("$dirpath/$testname");
        open my $fh, ">", "$dirpath/$testname";
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


sub mkfilepath {
    my ($name) = @_;
    my $dirpath = dirname($name);
    mkpath($dirpath, 0) unless -d $dirpath;
}


1;
