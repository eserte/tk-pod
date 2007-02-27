# Copyright (C) 2003,2006,2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

# Parts taken from TkTest.pm from Perl/Tk

package TkTest;

use strict;
use vars qw(@EXPORT);

use base qw(Exporter);
@EXPORT    = qw(check_display_harness);

sub check_display_harness () {
    # In case of cygwin, use'ing Tk before forking (which is done by
    # Test::Harness) may lead to "remap" errors, which are normally
    # solved by the rebase or rebaseall utilities.
    #
    # Here, I just skip the DISPLAY check on cygwin to not force users
    # to run rebase.
    #
    return if $^O eq 'cygwin' || $^O eq 'MSWin32';

    eval q{
           use blib;
           use Tk;
        };
    die "Strange: could not load Tk library: $@" if $@;

    if (defined $Tk::platform && $Tk::platform eq 'unix') {
	my $mw = eval { MainWindow->new() };
	if (!Tk::Exists($mw)) {
	    warn "Cannot create MainWindow (maybe no X11 server is running or DISPLAY is not set?)\n$@\n";
	    exit 0;
	}
	$mw->destroy;
    }
}

1;

__END__
