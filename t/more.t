#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: more.t,v 1.1 2004/02/06 10:39:39 eserte Exp $
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
	print "1..1\n";
	print "ok 1 # skip: tests only work with installed Test module\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

my $mw = tkinit;
my $more = $mw->Scrolled("More",
			 -font => "Courier 10",
			 -scrollbars => "osoe",
			)->pack(-fill => "both", -expand => 1);
$more->focus;
$more->Load($INC{"Tk/More.pm"});
$more->update;
ok(Tk::Exists($more));
if (!$ENV{PERL_INTERACTIVE_TEST}) {
    $mw->after(1*1000, sub { $mw->destroy });
}
MainLoop;

