#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use Cwd qw(cwd);
use FindBin;
use File::Basename qw(basename);
use File::Spec;
use Getopt::Long;

use lib $FindBin::RealBin;
use TkTest qw(display_test);
BEGIN {
    display_test();
}

BEGIN {
    if (!eval q{
	use Test::More;
	use POSIX ":sys_wait_h";
	use File::Temp qw(tempfile tempdir);
	1;
    }) {
	print "1..0 # skip no Test::More and/or POSIX module\n";
	CORE::exit(0);
    }
    if ($^O eq 'MSWin32') {
	print "1..0 # skip not on Windows\n"; # XXX but why?
	CORE::exit(0);
    }
}

my $DEBUG = 0;

my $blib   = File::Spec->rel2abs("$FindBin::RealBin/../blib");
my $script = "$blib/script/tkpod";
my $tkmore_script = "$blib/script/tkmore";

my $batch_mode = defined $ENV{BATCH} ? $ENV{BATCH} : 1;

my $cwd = cwd;
# http://rt.cpan.org/Ticket/Display.html?id=41320 (have to chdir out
# of temp directory before File::Temp cleans directories)
END { chdir $cwd if defined $cwd }

GetOptions("d|debug" => \$DEBUG,
	   "batch!" => \$batch_mode)
    or die "usage: $0 [-debug] [-nobatch]";

# Create test directories/files:
my $testdir = tempdir("tkpod_XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
die "Can't create temporary directory: $!" if !$testdir;

my $cpandir = "$testdir/CPAN";
mkdir $cpandir, 0777 or die "Cannot create temporary directory: $!";

my $cpanfile = "$testdir/CPAN.pm";
{
    open FH, "> $cpanfile"
	or die "Cannot create $cpanfile: $!";
    print FH "=pod\n\nTest\n\n=cut\n";
    close FH
	or die "While closing: $!";
}

my $obscurepod = "ThisFileReallyShouldNotExistInAPerlDistroXYZfooBAR";
my $obscurefile = "$testdir/$obscurepod.pod";
{
    open FH, "> $obscurefile"
	or die "Cannot create $obscurefile: $!";
    print FH "=pod\n\nThis is: $obscurepod\n\n=cut\n";
    close FH
	or die "While closing: $!";
}

my @opt = (
	   ['-tk'],
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

	   # Environment settings
	   ['-tree', '__ENV__', TKPODCACHE => "$testdir/pods_%v_%o_%u"],
	   ['__ENV__', TKPODDEBUG => 1],
	   ['__ENV__', TKPODEDITOR => 'ptked'],
	   [$obscurepod.".pod", '__ENV__', TKPODDIRS => $testdir],

	   # tkmore
	   ['__SCRIPT__', $tkmore_script, $0],
	   ['__SCRIPT__', $tkmore_script, "-xrm", "*fixedFont:{monospace 10}", $0],
	   ['__SCRIPT__', $tkmore_script, "-font", "monospace 10", $0],
	   ['__SCRIPT__', $tkmore_script, "$FindBin::RealBin/testdata/latin1.txt"],
	   ['__SCRIPT__', $tkmore_script, -encoding => "utf-8", "$FindBin::RealBin/testdata/utf8.txt"],
	   ['__SCRIPT__', $tkmore_script, -encoding => "utf-8", "$FindBin::RealBin/testdata/utf8.txt.gz"],

	   # This should be near end...
	   ['__ACTION__', chdir => $testdir ],
	   ["CPAN"],

	   # Cleanup (jump out of $testdir, so File::Temp cleanup does not fail)
	   ['__ACTION__', chdir => $FindBin::RealBin ],
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

    local %ENV = %ENV;
    delete $ENV{$_} for qw(TKPODCACHE TKPODDEBUG TKPODDIRS TKPODEDITOR);

    my $this_script = $script;

    my @this_opts;
    my @this_env;
    for(my $i = 0; $i<=$#$opt; $i++) {
	if ($opt->[$i] eq '__ENV__') {
	    $ENV{$opt->[$i+1]} = $opt->[$i+2];
	    push @this_env, $opt->[$i+1]."=".$opt->[$i+2];
	    $i+=2;
	} elsif ($opt->[$i] eq '__SCRIPT__') {
	    $this_script = $opt->[$i+1];
	    $i+=1;
	} else {
	    push @this_opts, $opt->[$i];
	}
    }

    my $testname = "Trying " . basename($this_script) . " with @this_opts";
    if (@this_env) {
	$testname .= ", environment " . join(", ", @this_env);
    }

    if ($batch_mode) {
	my $pid = fork;
	if ($pid == 0) {
	    run_tkpod($this_script, \@this_opts);
	}
	for (1..10) {
	    select(undef,undef,undef,0.05);
	    my $kid = waitpid($pid, WNOHANG);
	    if ($kid) {
		is($?, 0, $testname);
		next OPT;
	    }
	}
	kill TERM => $pid;
	for (1..10) {
	    select(undef,undef,undef,0.05);
	    if (!kill 0 => $pid) {
		pass($testname);
		next OPT;
	    }
	}
	kill KILL => $pid;
	pass($testname);
    } else {
	run_tkpod($this_script, \@this_opts);
	pass($testname);
    }
}

sub run_tkpod {
    my($script, $this_opts_ref) = @_;
    my @cmd = ($^X, "-Mblib=$blib", $script, "-geometry", "+10+10", @$this_opts_ref);
    warn "@cmd\n" if $DEBUG;
    if ($batch_mode) {
	open(STDERR, ">" . File::Spec->devnull) unless $DEBUG;
	exec @cmd;
	die $!;
    } else {
	system @cmd;
	if ($? == 2) {
	    die "Aborted by user...\n";
	}
	if ($? != 0) {
	    warn "<@cmd> failed with status code <$?>";
	}
    }
}

__END__
