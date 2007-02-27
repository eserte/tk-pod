#!/usr/bin/perl
# -*- perl -*-

#
# $Id: optionalmods.t,v 1.4 2007/02/27 21:47:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
# 	require Test::Without::Module;
# 	die "Problems with Test::Without::Module 0.09"
# 	    if $Test::Without::Module::VERSION eq '0.09';
	$ENV{DEVEL_HIDE_PM} = "";
	$ENV{DEVEL_HIDE_VERBOSE} = 0;
	require Devel::Hide;
	1;
    }) {
#	print "1..0 # skip: no Test::More and/or Test::Without::Module (!= 0.09) modules\n";
	print "1..0 # skip: no Test::More and/or Devel::Hide modules\n";
	exit;
    }
}

#use Test::Without::Module qw(Text::English Tk::HistEntry Tk::ToolBar);
use Devel::Hide qw(Text::English Tk::HistEntry Tk::ToolBar);

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
