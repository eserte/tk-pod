#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: more.t,v 1.5 2009/10/10 15:55:34 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::More;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip tests only work with installed Test module\n";
	CORE::exit(0);
    }
}

my $mw = eval { tkinit };
if (!$mw) {
    print "1..0 # cannot create MainWindow\n";
    CORE::exit(0);
}

plan tests => 2;

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

