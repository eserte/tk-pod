#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cmdline.t,v 1.2 2003/02/05 14:46:29 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use File::Spec;

BEGIN {
    if (!eval q{
	use Test;
	use POSIX ":sys_wait_h";
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
    if ($ENV{BATCH} || $^O eq 'MSWin32') {
	print "1..0 # skip: not on Windows or in BATCH mode\n";
	exit;
    }
}

BEGIN { plan tests => 6 }

my $script = 'blib/script/tkpod';

my @opt = (['-tk'],
	   ['-tree','-geometry','+0+0'],
	   ['-notree'],
	   ['-Mblib'],
	   #['-Iblib/lib'],
	   ['-d'],
	   ['-server'],
	  );
OPT:
for my $opt (@opt) {
    my $pid = fork;
    if ($pid == 0) {
	my @cmd = ($^X, "-Mblib", $script, @$opt);
	#warn "@cmd\n";
	open(STDERR, ">" . File::Spec->devnull);
	exec @cmd;
	die $!;
    }
    for (1..10) {
	select(undef,undef,undef,0.1);
	my $kid = waitpid($pid, WNOHANG);
	if ($kid) {
	    ok($?, 0);
	    next OPT;
	}
    }
    kill TERM => $pid;
    for (1..10) {
	select(undef,undef,undef,0.1);
	if (!kill 0 => $pid) {
	    ok(1);
	    next OPT;
	}
    }
    kill KILL => $pid;
    ok(1);
}

__END__
