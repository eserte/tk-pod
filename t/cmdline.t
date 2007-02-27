#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cmdline.t,v 1.6 2007/01/27 19:58:54 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Spec;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	use POSIX ":sys_wait_h";
	use File::Temp qw(tempfile tempdir);
	1;
    }) {
	print "1..0 # skip: no Test::More and/or POSIX module\n";
	exit;
    }
    if ($ENV{BATCH} || $^O eq 'MSWin32') {
	print "1..0 # skip: not on Windows or in BATCH mode\n";
	exit;
    }
}

my $DEBUG = 0;

my $blib   = File::Spec->rel2abs("$FindBin::RealBin/../blib");
my $script = "$blib/script/tkpod";

GetOptions("d|debug" => \$DEBUG)
    or die "usage: $0 [-debug]";

# Create test directories/files:
my $testdir = tempdir("tkpod_XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
die "Can't create temporary directory: $!" if !$testdir;

my $cpandir = "$testdir/CPAN";
mkdir $cpandir or die "Cannot create temporary directory: $!";

my $cpanfile = "$testdir/CPAN.pm";
{
    open my $fh, ">", $cpanfile
	or die "Cannot create $cpanfile: $!";
    print $fh "=pod\nTest\n=cut\n";
    close $fh
	or die "While closing: $!";
}

my @opt = (['-tk'],
	   ['-tree','-geometry','+0+0'],
	   ['-notree'],
	   ['-Mblib'],
	   #['-Iblib/lib'],
	   ['-d'],
	   ['-server'],
	   ['-xrm', '*font: {nimbus sans l} 24',
	    '-xrm', '*serifFont: {nimbus roman no9 l}',
	    '-xrm', '*sansSerifFont: {nimbus sans l}',
	    '-xrm', '*monospaceFont: {nimbus mono l}',
	   ],
	   [$script], # the pod of tkpod itself
	   # This should be near end...
	   ['__ACTION__', chdir => $testdir ],
	   ["CPAN"],
	  );

plan tests => scalar @opt;

OPT:
for my $opt (@opt) {
    if ($opt->[0] eq '__ACTION__') {
	my $action = $opt->[1];
	if ($action eq 'chdir') {
	    chdir $opt->[2] or die $!;
	} else {
	    die "Unknown action $action";
	}
	pass "Just setting an action...";
	next;
    }

    my $pid = fork;
    if ($pid == 0) {
	my @cmd = ($^X, "-Mblib=$blib", $script, "-geometry", "+10+10", @$opt);
	warn "@cmd\n" if $DEBUG;
	open(STDERR, ">" . File::Spec->devnull) unless $DEBUG;
	exec @cmd;
	die $!;
    }
    for (1..10) {
	select(undef,undef,undef,0.1);
	my $kid = waitpid($pid, WNOHANG);
	if ($kid) {
	    is($?, 0, "Trying tkpod with @$opt");
	    next OPT;
	}
    }
    kill TERM => $pid;
    for (1..10) {
	select(undef,undef,undef,0.1);
	if (!kill 0 => $pid) {
	    pass("Trying tkpod with @$opt");
	    next OPT;
	}
    }
    kill KILL => $pid;
    pass("Trying tkpod with @$opt");
}

__END__
