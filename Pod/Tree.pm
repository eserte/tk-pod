# -*- perl -*-

#
# $Id: Tree.pm,v 1.1 2001/06/13 08:05:25 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Pod::Tree;

use strict;
use vars qw($VERSION @ISA @POD);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use Tk::Pod::FindPods;

use base 'Tk::Tree';

Construct Tk::Widget 'PodTree';

BEGIN { @POD = @INC }

sub Dir {
    my $class = shift;
    unshift @POD, @_;
}

sub Populate {
    my($w,$args) = @_;

    $args->{-separator} = "/";
    $args->{-command} = sub {
	my $data = $w->info('data', $_[0]);
	if ($data) {
	    $w->Callback(-showcommand => $w, $data);
	}
    };

    $w->SUPER::Populate($args);

    $w->ConfigSpecs(
	-showcommand => ['CALLBACK', undef, undef, undef],
    );
}

sub Fill {
    my $w = shift;

    $w->delete("all");

    my %pods = Tk::Pod::FindPods::pod_find(-categorized => 1);
    my %category_seen;

    foreach (['perl',   'Perl language'],
	     ['pragma', 'Pragmata'],
	     ['mod',    'Modules'],
	     keys %pods,
	    ) {
	my($category, $title) = (ref $_ ? @$_ : ($_, $_));
	next if $category_seen{$category};

	$w->add($category, -text => $title);

	my $hash = $pods{$category};
	foreach my $pod (sort keys %$hash) {
	    next if $pod =~ /\./;#XXX

	    my $treepath = "$category/$pod";
	    (my $title = $pod) =~ s|/|::|g;
	    $w->_add_parents($treepath);
	    my @entry_args = ($treepath,
			      -text => $title,
			      -data => {File => $hash->{$pod}},
			     );
	    if ($w->info('exists', $treepath)) {
		$w->entryconfigure(@entry_args);
	    } else {
		$w->add(@entry_args);
	    }
	}

	$category_seen{$category}++;
    }

    for(my $entry = ($w->info('children'))[0];
	   defined $entry && $entry ne "";
	   $entry = $w->info('next', $entry)) {
	if ($w->info('children', $entry)) {
	    $w->entryconfigure($entry, -image => $w->Getimage("folder"));
	    $w->setmode($entry, 'open');
	    if ($entry =~ m|/|) {
		$w->hide('entry', $entry);
	    }
	} else {
	    $w->entryconfigure($entry, -image => $w->Getimage("file"));
	    $w->hide('entry', $entry);
	}
    }
}

sub _add_parents {
    my($w, $entry) = @_;
    (my $parent = $entry) =~ s|/[^/]+$||;
    return if $parent eq '';
    return if $w->info('exists', $parent);
    my @parent = split '/', $parent;
    my $title = join "::", @parent[1..$#parent];
    $w->_add_parents($parent);
    $w->add($parent, -text => $title);
}


1;

__END__

=head1 NAME

Tk::Pod::Tree - list POD file hierarchy


=head1 SYNOPSIS

    use Tk::Pod::Tree;

    $parent->PodTree;

=head1 DESCRIPTION



=head1 SEE ALSO



=head1 AUTHOR

Slaven Rezic <F<slaven.rezic@berlin.de>>

Copyright (c) 2001 Slaven Rezic.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
