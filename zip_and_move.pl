#! /usr/bin/env perl

package Main;
use feature qw(say);
use strict;
use warnings;
use Data::Dumper;
use File::Basename qw(basename);
use File::Spec;
{
    my $self = Main->new(
        sourcedir => '/home/project/work/karen/data/env/hold',
        destdir   => '/home/project/work/karen/data/env/PROD',
        maxfiles  => 1000,
        maxsize   => 10_000_000,         # 1 Mb = 1_000_000 bytes
    );
   
    $self->init();
    $self->get_files();
    $self->start_new_archive();
    while ($self->{cur_files_left} > 0) {
        $self->add_file();
        if ($self->{cur_num_arch_files} >= $self->{maxfiles}) {
            $self->start_new_archive();
        }
        elsif ($self->cur_arch_size() >= $self->{maxsize}) {
            $self->start_new_archive();
        }
    }
    say "Done.";
}

sub add_file {
    my ( $self ) = @_;
    my $files = $self->{files};
    die "Unexpected, no file names in array" if @$files == 0;
    my $fn = shift @$files;
    die "Unexpected, file does not exist" if !(-e $fn && -f $fn);
    $self->{sum_file_sizes} += -s $fn;
    say ".. $fn";
    system "zip", "-q", $self->{zip_fn}, $fn;
    $self->{cur_files_left} = scalar @$files;
    $self->{cur_num_arch_files} += 1;
}

sub cd {
    my ( $self,  $dir ) = @_;

    chdir $dir or die "Could not chdir to '$dir': $!";
}

sub cur_arch_size {
    my ( $self ) = @_;

    my $fn = $self->{zip_fn};
    die "Unexpected, file does not exist" if !(-e $fn && -f $fn);
    return -s $fn;
}

sub get_files {
    my ( $self ) = @_;

    $self->cd( $self->{sourcedir} );
    my @files = sort <*.gz>;
    $self->{files} = \@files;
    $self->{cur_files_left} = scalar @files;
}

sub init {
    my ( $self ) = @_;

    $self->{zip_count} = 0;
    $self->{cur_num_arch_files} = 0;
    $self->{sourcedir} = File::Spec->rel2abs($self->{sourcedir});
    $self->{destdir} = File::Spec->rel2abs($self->{destdir});
    $self->{zip_fn} = undef;
    $self->{sum_file_sizes} = 0;
}

sub new {
    my ( $class, %args ) = @_;

    return bless \%args, $class;
}

sub start_new_archive {
    my ( $self ) = @_;

    my $zfn = $self->{zip_fn};
    if (defined $zfn) {
        my $zsz = -s $zfn;
        $zfn = basename $zfn;
        my $N = $self->{cur_num_arch_files};
        my $fsz = $self->{sum_file_sizes};
        say "Finished with $zfn (size: $zsz), $N files added (size: $fsz)";
    }
    $self->{sum_file_sizes} = 0;
    my $date = qx'date -d "now" +"%Y%m%d%H%M"';
    chomp $date;
    $self->{zip_count} += 1;
    my $count = sprintf "%04d", $self->{zip_count};
    my $fn = $count . "_" . $date . ".zip";
    $self->{zip_fn} = File::Spec->catfile($self->{destdir}, $fn);
    $self->{cur_num_arch_files} = 0;
}
