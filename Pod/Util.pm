# -*- perl -*-

#
# $Id: Util.pm,v 1.4 2003/08/01 10:43:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Pod::Util;
use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw(Exporter);
@EXPORT_OK = qw(is_in_path is_interactive detect_window_manager);

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository
# REPO MD5 1b42243230d92021e6c361e37c9771d1

sub is_in_path {
    my($prog) = @_;
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd"
		   );
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

sub is_interactive {
    if ($^O eq 'MSWin32' || !eval { require POSIX; 1 }) {
	# fallback
	return -t STDIN && -t STDOUT;
    }

    # from perlfaq8
    open(TTY, "/dev/tty") or die $!;
    my $tpgrp = POSIX::tcgetpgrp(fileno(*TTY));
    my $pgrp = getpgrp();
    if ($tpgrp == $pgrp) {
	1;
    } else {
	0;
    }
}

sub detect_window_manager {
    my $top = shift;
    if ($Tk::platform eq 'MSWin32') {
	return "win32";
    }
    if (   get_property($top, "GNOME_NAME_SERVER")) {
	return "gnome";
    }
    if (   get_property($top, "KWM_RUNNING") # KDE 1
	|| get_property($top, "KWIN_RUNNING") # KDE 2
       ) {
	return "kde";
    }
    "x11"; # generic X11 window manager
}

sub get_property {
    my($top, $prop) = @_;
    my @ret;
    if ($top->property('exists', $prop, 'root')) {
	@ret = $top->property('get', $prop, 'root');
	shift @ret; # get rid of property name
    }
    @ret;
}

1;

__END__

=head1 NAME

Tk::Pod::Util - Tk::Pod specific utility functions

=head1 DESCRIPTION

This module contains a collection of utility functions for Tk::Pod.

=cut
