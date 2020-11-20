#! /usr/bin/env perl

use feature qw(say);
use strict;
use warnings;
use Data::Dumper;
use File::Basename qw(basename);
use File::Spec;
use Getopt::Long;

{
	my $infile = 'source_dir_ref.txt';
	my $file = $ARGV[0];

	GetOptions ("infile=s" => \$file ) or die("Error in command line arguments\n");

	open(DATA, $infile) or die "Couldn't open file $file";
	my @listdir;
	@listdir = <DATA>;
	chomp @listdir;

	
	my @sourcedirs = @listdir;

	my @des = @listdir;
	for (@des){
	s{/STAGING}{};
	}
	my @destdirs = @des;

    my $maxfiles  = 1000;
    my $maxsize = 10000000;
    for my $idx (0..$#sourcedirs) {
        my $src = $sourcedirs[$idx];
        my $dst = $destdirs[$idx];
        say "\nWorking on sourcedir: $src, destdir: $dst ..\n";
        my $zip = ZipDir->new(
            sourcedir => $src,
            destdir   => $dst,
            maxfiles  => $maxfiles,
            maxsize   => $maxsize,
        );
        $zip->init();
        $zip->get_files();
        $zip->start_new_archive();
        while ($zip->{cur_files_left} > 0) {
            $zip->add_file();
            if ($zip->{cur_num_arch_files} >= $zip->{maxfiles}) {
                $zip->start_new_archive();
            }
            elsif ($zip->cur_arch_size() >= $zip->{maxsize}) {
                $zip->start_new_archive();
            }
        }
        $zip->cleanup();
    }
    say "Done.";
}

package ZipDir;
use Cwd qw(getcwd);
use Data::Dumper;
use File::Basename qw(basename dirname);
use File::Spec;


sub add_file {
    my ( $self ) = @_;
    my $files = $self->{files};
    die "Unexpected, no file names in array" if @$files == 0;
    my $fn = shift @$files;
    die "Unexpected, file does not exist" if !(-e $fn && -f $fn);
    $self->{sum_file_sizes} += -s $fn;
    say ".. $fn";
    my $res = system "zip", "-q", $self->{zip_fn}, $fn;
    if ( $res != 0 ) {
        my $ret_val = $res >> 8;
        die "Failed to execute zip command. zip returned exit code $ret_val";
    }
    unlink $fn or die "Could not delete file '$fn': $!";
    $self->{cur_files_left} = scalar @$files;
    $self->{cur_num_arch_files} += 1;
}

sub cd {
    my ( $self,  $dir ) = @_;

    chdir $dir or die "Could not chdir to '$dir': $!";
}

sub cleanup {
    my ( $self ) = @_;

    $self->cd( $self->{cwd} );
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

    $self->{cwd} = getcwd();
    $self->{zip_count} = 0;
    $self->{cur_num_arch_files} = 0;
    $self->{sourcedir} = File::Spec->rel2abs($self->{sourcedir});
    $self->{parent_dir_name} = basename(dirname( $self->{sourcedir} ));
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
    #my $fn = $count . "_" . $date . ".zip";
    my $fn = $self->{parent_dir_name} . "_" . $date . "_" . $count . ".zip";
    $self->{zip_fn} = File::Spec->catfile($self->{destdir}, $fn);
    $self->{cur_num_arch_files} = 0;
}
