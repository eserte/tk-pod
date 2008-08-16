#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: pods.t,v 1.3 2008/08/16 20:37:53 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::Pod::Text;

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
	print "1..0 # skip no Test module\n";
	CORE::exit(0);
    }
}

BEGIN { plan tests => 4 }

use Tk;
my $mw = MainWindow->new;
my $pt = $mw->PodText->pack;
for my $pod ('perl',       # pod in perl.pod
	     'perldoc',    # pod in script itself
	     'strict',     # sample pragma pod
	     'File::Find', # sample module pod
	    ) {
    $pt->configure(-file => $pod);
    ok($pt->cget(-file), $pod);
}

#MainLoop;

__END__
