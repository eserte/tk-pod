# -*- perl -*-

#
# $Id: Tree.pm,v 1.8 2001/06/18 18:47:05 eserte Exp $
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

=head1 NAME

Tk::Pod::Tree - list POD file hierarchy


=head1 SYNOPSIS

    use Tk::Pod::Tree;

    $parent->PodTree;

=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item Name: B<-showcommand>

Specifies a callback for selecting a POD module (Button-1 binding).

=item Name: B<-showcommand2>

Specifies a callback for selecting a POD module in a different window
(Button-2 binding).

=item Name: B<-usecache>

True, if a cache of POD modules should be created and used. The
default is true.

=back

=head1 DESCRIPTION

The B<Tk::Pod::Tree> widget shows all available Perl POD documentation
in a tree.

=cut

use strict;
use vars qw($VERSION @ISA @POD);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use base 'Tk::Tree';

use Tk::Pod::FindPods qw/%pods $has_cache pod_find/;
use Tk::ItemStyle;
use Tk qw(Ev);

Construct Tk::Widget 'PodTree';

BEGIN { @POD = @INC }

sub Dir {
    my $class = shift;
    unshift @POD, @_;
}

sub ClassInit {
    my ($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);
    $mw->bind($class, '<3>', ['PostPopupMenu', Ev('X'), Ev('Y')]  );
}

sub Populate {
    my($w,$args) = @_;

    $args->{-separator} = "/";

    my $show_command = sub {
	my $w = shift;
	my $cmd = shift || '-showcommand';

	my $Ev = $w->XEvent;
	my $ent = $w->GetNearest($Ev->y, 1);
	return unless (defined $ent and length $ent);

	my @info = $w->info('item',$Ev->x, $Ev->y);
	if (defined $info[1] && $info[1] eq 'indicator') {
	    $w->Callback(-indicatorcmd => $ent, '<Arm>');
	    return;
	}

	my $data = $w->info('data', $ent);
	if ($data) {
	    $w->Callback($cmd, $w, $data);
	}
    };

    foreach (qw/1 space Return/) {
	$w->bind("<$_>" => sub { $show_command->(shift) });
    }
    foreach (qw/2 Shift-1/) {
	$w->bind("<$_>" => sub { $show_command->(shift, '-showcommand2') });
    }

    $w->SUPER::Populate($args);

    $w->{CoreIS}   = $w->ItemStyle('imagetext', -foreground => '#006000');
    $w->{SiteIS}   = $w->ItemStyle('imagetext', -foreground => '#e08000');
    $w->{FolderIS} = $w->ItemStyle('imagetext', -foreground => '#606060');

    my $m = $w->Menu(-tearoff => $Tk::platform ne 'MSWin32');
    $w->menu($m);
    $m->command(-label => 'Reload', -command => sub {
		    $w->Busy(-recurse => 1);
		    eval {
			$w->Fill(-nocache => 1);
		    };
		    my $err = $@;
		    $w->Unbusy(-recurse => 1);
		    die $err if $err;
		});

    $w->ConfigSpecs(
	-showcommand  => ['CALLBACK', undef, undef, undef],
	-showcommand2 => ['CALLBACK', undef, undef, undef],
	-usecache     => ['PASSIVE', undef, undef, 1],
    );
}

=head1 WIDGET METHODS

=over 4

=item I<$tree>-E<gt>B<Fill>(?I<-nocache =E<gt> 1>?)

Find POD modules and fill the tree widget. If I<-nocache> is
specified, then no cache will be used for loading.

A cache of POD modules is written unless the B<-usecache>
configuration option of the widget is set to false.

=cut

sub Fill {
    my $w = shift;
    my(%args) = @_;

    $w->delete("all");

    my $usecache = ($w->cget('-usecache') && !$args{'-nocache'});

    # fills %pods hash:
    pod_find(-categorized => 1, -usecache => $usecache);

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

	    my $is = Tk::Pod::FindPods::is_site_module($hash->{$pod})
		     ? $w->{SiteIS}
		     : $w->{CoreIS};
	    my @entry_args = ($treepath,
			      -text => $title,
			      -data => {File => $hash->{$pod}},
			      ($is ? (-style => $is) : ()),
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

    if ($w->cget('-usecache') && !$Tk::Pod::FindPods::has_cache) {
	Tk::Pod::FindPods::WriteCache();
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
    $w->add($parent, -text => $title,
	    ($w->{FolderIS} ? (-style => $w->{FolderIS}) : ()));
}

sub _open_parents {
    my($w, $entry) = @_;
    (my $parent = $entry) =~ s|/[^/]+$||;
    return if $parent eq '' || $parent eq $entry;
    $w->_open_parents($parent);
    $w->open($parent);
}

=item I<$tree>-E<gt>B<SeePath>($path)

Move the anchor/selection and view to the given C<$path> and open
subtrees to make the C<$path> visible, if necessary.

=cut

sub SeePath {
    my($w,$path) = @_;
    foreach my $category (keys %pods) {
	foreach my $pod (keys %{ $pods{$category} }) {
	    my $podpath = $pods{$category}->{$pod};
	    if ($path eq $podpath) {
		my $treepath = "$category/$pod";
		$w->open($treepath);
		$w->_open_parents($treepath);
		$w->anchorSet($treepath);
		$w->selectionClear;
		$w->selectionSet($treepath);
		$w->see($treepath);
		return 1;
	    }
	}
    }
    0;
}

1;

__END__

=back

=head1 SEE ALSO

Tk::Tree(3), Tk::Pod(3), tkpod(1), Tk::Pod::FindPods(3).

=head1 AUTHOR

Slaven Rezic <F<slaven.rezic@berlin.de>>

Copyright (c) 2001 Slaven Rezic.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
