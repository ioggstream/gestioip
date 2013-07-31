#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Test::Harness;

$Test::Harness::verbose = 1;
use lib './modules';

sub main
{

    my $testdir = "./test";
    my @tests_to_run;

    opendir TESTDIR, $testdir or die "cannot open directory $testdir: $!";
    while ( my $filename = readdir(TESTDIR) ) {
        next if ($filename =~ m/^\./);
        next if ($filename !~ m/(.+)\.t$/);
        next if ( defined $ARGV[0] and $1 ne $ARGV[0] );
        push @tests_to_run, "$testdir/$filename";
    }
    closedir TESTDIR;

    runtests (@tests_to_run);

    return 0;
}

&main;
exit 0;
