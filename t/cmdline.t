#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cmdline.t,v 1.4 2006/09/01 20:10:06 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use File::Spec;

BEGIN {
    if (!eval q{
	use Test::More;
	use POSIX ":sys_wait_h";
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
    if ($ENV{BATCH} || $^O eq 'MSWin32') {
	print "1..0 # skip: not on Windows or in BATCH mode\n";
	exit;
    }
}

my $DEBUG = 0;
my $script = 'blib/script/tkpod';

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
	  );

plan tests => scalar @opt;

OPT:
for my $opt (@opt) {
    my $pid = fork;
    if ($pid == 0) {
	my @cmd = ($^X, "-Mblib", $script, "-geometry", "+10+10", @$opt);
	warn "@cmd\n" if $DEBUG;
	open(STDERR, ">" . File::Spec->devnull);
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
