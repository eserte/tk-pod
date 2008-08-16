#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: podtree.t,v 1.4 2008/08/16 18:42:51 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::Pod::Tree;
use Tk::Pod::FindPods;

use FindBin;
use lib $FindBin::RealBin;
use TkTest qw(display_test);
BEGIN {
    display_test();
}

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 5 }

my $mw = tkinit;

my $pt;
$pt = $mw->Scrolled("PodTree",
		    -scrollbars => "osow",
		    -showcommand => sub {
			warn $_[1]->{File};
		    },
		   )->grid(-sticky => "esnw");
$mw->gridColumnconfigure(0, -weight => 1);
$mw->gridRowconfigure(0, -weight => 1);

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
