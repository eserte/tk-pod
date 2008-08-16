#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: subclass.t,v 1.2 2008/08/16 18:42:51 eserte Exp $
# Author: Slaven Rezic
#

# Subclassing test --- use Tk::ROText instead of Tk::More
# as the pager in the PodText widget

use strict;

use Tk;
use Tk::Pod;

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

    if ($] < 5.006) {
	print "1..0 # skip subclassing does not work with perl 5.005 and lesser\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

{
    package Tk::MyMore;
    use base qw(Tk::Derived Tk::ROText);
    Construct Tk::Widget "MyMore";
    sub Populate {
	my($w, $args) = @_;
	$w->SUPER::Populate($args);
	$w->Advertise(text => $w); # XXX hmmmm....
	$w->ConfigSpecs(-searchcase => ['PASSIVE'],
			-helpcommand => ['PASSIVE'],
		       );
    }
}

{
    package Tk::MyPodText;
    use base qw(Tk::Pod::Text);
    Construct Tk::Widget "MyPodText";
    sub More_Module { }
    sub More_Widget { "MyMore" }
}

{
    package Tk::MyPod;
    use base qw(Tk::Pod);
    Construct Tk::Widget "MyPod";
    sub Pod_Text_Module { }
    sub Pod_Text_Widget { "MyPodText" }
}

my $mw = MainWindow->new;
$mw->withdraw;
my $pod = $mw->MyPod;
$pod->configure(-file => "perl.pod");
$mw->update;
ok(1);

if (!$ENV{PERL_INTERACTIVE_TEST}) {
    $mw->after(1*1000, sub { $mw->destroy });
}

MainLoop;
