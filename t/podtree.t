#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::Pod::Tree;
use Tk::Pod::FindPods;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	CORE::exit(0);
    }
}

my $mw = eval { tkinit };
if (!$mw) {
    print "1..0 # cannot create MainWindow\n";
    CORE::exit(0);
}
$mw->geometry("+1+1"); # for twm

plan tests => 5;

my $pt;
$pt = $mw->Scrolled("PodTree",
		    -scrollbars => "osow",
		    -showcommand => sub {
			warn $_[1]->{File};
		    },
		   )->grid(-sticky => "esnw");
$mw->gridColumnconfigure(0, -weight => 1);
$mw->gridRowconfigure(0, -weight => 1);

warn <<EOF;
#
# Tests may take a long time (up to 10 minutes or so) if you have a lot
# of modules installed.
EOF

ok(Tk::Exists($pt), 1);
$pt->Fill;
ok(1);

my $FindPods = Tk::Pod::FindPods->new;
ok($FindPods->isa("Tk::Pod::FindPods"));
my $pods = $FindPods->pod_find(-categorized => 1, -usecache => 1);
ok(UNIVERSAL::isa($pods, "HASH"));
my $path = $pods->{perl}{ (keys %{ $pods->{perl} })[0] };
$pt->SeePath($path);
ok(1);

$mw->after(1*1000,sub{$mw->destroy});
MainLoop;

__END__
