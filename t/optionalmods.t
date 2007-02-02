#!/usr/bin/perl
# -*- perl -*-

#
# $Id: optionalmods.t,v 1.3 2007/02/02 07:41:31 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	require Test::Without::Module;
	die "Problems with Test::Without::Module 0.09"
	    if $Test::Without::Module::VERSION eq '0.09';
	1;
    }) {
	print "1..0 # skip: no Test::More and/or Test::Without::Module (!= 0.09) modules\n";
	exit;
    }
}

use Test::Without::Module qw(Text::English Tk::HistEntry Tk::ToolBar);

use Tk;
use Tk::Pod;

plan tests => 1;

my $mw = tkinit;
$mw->geometry("+0+0");

my $pod = $mw->Pod;
$pod->idletasks;
ok(Tk::Exists($pod));

if (defined $ENV{BATCH} && !$ENV{BATCH}) {
    MainLoop;
}

__END__
