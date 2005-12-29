#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: optionalmods.t,v 1.1 2005/12/29 22:26:35 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use Test::Without::Module;
	1;
    }) {
	print "1..0 # skip: no Test::More and/or Test::Without::Module modules\n";
	exit;
    }
}

use Tk;
use Tk::Pod;

plan tests => 1;

my $mw = tkinit;
$mw->geometry("+0+0");

use Test::Without::Module qw(Text::English Tk::HistEntry Tk::ToolBar);

my $pod = $mw->Pod;
$pod->idletasks;
ok(Tk::Exists($pod));

if (defined $ENV{BATCH} && !$ENV{BATCH}) {
    MainLoop;
}

__END__
