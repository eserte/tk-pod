#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: pods.t,v 1.1 2003/11/12 00:47:48 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Tk;
use Tk::Pod::Text;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
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
