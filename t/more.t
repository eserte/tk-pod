#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: more.t,v 1.3 2008/08/16 18:42:50 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::More;

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
	print "1..0 # skip tests only work with installed Test module\n";
	exit;
    }
}

BEGIN { plan tests => 2 }

my $mw = tkinit;

{
    my $more = $mw->Scrolled("More",
			     -font => "Courier 10",
			     -scrollbars => "osoe",
			    )->pack(-fill => "both", -expand => 1);
    $more->focus;
    $more->Load($INC{"Tk/More.pm"});
    $more->update;
    ok(Tk::Exists($more));
}

{
    my $more = $mw->More
	(# -font: use default
	 -width => 20,
	 -height => 3,
	)->pack;
    $more->Load($0);
    $more->update;
    ok(Tk::Exists($more));
}

if (!$ENV{PERL_INTERACTIVE_TEST}) {
    $mw->after(1*1000, sub { $mw->destroy });
}
MainLoop;

