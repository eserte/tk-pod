#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: podtree.t,v 1.1 2001/06/13 08:05:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::Pod::Tree;

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

BEGIN { plan tests => 2 }

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
$mw->after(1*1000,sub{$mw->destroy});
MainLoop;

__END__
