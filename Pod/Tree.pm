# -*- perl -*-

#
# $Id: Tree.pm,v 1.16 2003/02/10 22:35:14 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

use base 'Tk::Tree';

use Tk::Pod::FindPods qw/%pods $has_cache pod_find/;
use Tk::ItemStyle;
use Tk qw(Ev);

Construct Tk::Widget 'PodTree';

BEGIN { @POD = @INC }

BEGIN {  # Make a DEBUG constant very first thing...
  if(defined &DEBUG) {
  } elsif(($ENV{'TKPODDEBUG'} || '') =~ m/^(\d+)/) { # untaint
    eval("sub DEBUG () {$1}");
    die "WHAT? Couldn't eval-up a DEBUG constant!? $@" if $@;
  } else {
    *DEBUG = sub () {0};
  }
}

######################################################################
use Class::Struct;
struct '_PodEntry' => [
    'uri'  => "\$",
];
sub _PodEntry::create {
    my $e = shift->new;
    $e->uri(shift);
    $e;
}
sub _PodEntry::file {
    my $uri = shift->uri;
    ($uri =~ /^file:(.*)/)[0];
}
######################################################################

sub Dir {
    my $class = shift;
    unshift @POD, @_;
}

sub ClassInit {
    my ($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);
    $mw->bind($class, '<3>', ['PostPopupMenu', Ev('X'), Ev('Y')]  )
	if $Tk::VERSION > 800.014;
}

sub Populate {
    my($w,$args) = @_;

    $args->{-separator} = "/";

    my $show_command = sub {
	my($w, $cmd, $ent) = @_;

	my $data = $w->info('data', $ent);
	if ($data) {
	    $w->Callback($cmd, $w, $data);
	}
    };

    my $show_command_mouse = sub {
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

	$show_command->($w, $cmd, $ent);
    };

    my $show_command_key = sub {
	my $w = shift;
	my $cmd = shift || '-showcommand';

	my($ent) = $w->selectionGet;
	return unless (defined $ent and length $ent);

	if ($w->info('children', $ent)) {
	    $w->open($ent);
	}

	$show_command->($w, $cmd, $ent);
    };

    $w->bind("<1>" => sub { $show_command_mouse->(shift) });
    foreach (qw/space Return/) {
  	$w->bind("<$_>" => sub { $show_command_key->(shift) });
    }

    foreach (qw/2 Shift-1/) {
	$w->bind("<$_>" => sub { $show_command_mouse->(shift, '-showcommand2') });
    }

    $w->SUPER::Populate($args);

    $w->{Style} = {};
    $w->{Style}{'core'} = $w->ItemStyle('imagetext', -foreground => '#006000');
    $w->{Style}{'site'} = $w->ItemStyle('imagetext', -foreground => '#702000');
    $w->{Style}{'cpan'} = $w->ItemStyle('imagetext', -foreground => '#000080');
    $w->{Style}{'folder'} = $w->ItemStyle('imagetext', -foreground => '#606060');

    my $m = $w->Menu(-tearoff => $Tk::platform ne 'MSWin32');
    eval { $w->menu($m) }; warn $@ if $@;
    $m->command(-label => 'Reload', -command => sub {
		    $w->Busy(-recurse => 1);
		    eval {
			$w->Fill(-nocache => 1);
		    };
		    my $err = $@;
		    $w->Unbusy(-recurse => 1);
		    die $err if $err;
		});
    $m->command(-label => 'Search...', -command => [$w, 'search_dialog']);
    $w->{Show_CPAN_CB} = 0;
    $m->checkbutton(-label => 'Show modules at CPAN',
		    -variable => \$w->{Show_CPAN_CB},
		    -command => sub {
			$w->Busy(-recurse => 1);
			eval {
			    $w->configure(-cpan => $w->{Show_CPAN_CB});
			};
			my $err = $@;
			$w->Unbusy;
			die $err if $err;
		    }),

    $w->ConfigSpecs(
	-showcommand  => ['CALLBACK', undef, undef, undef],
	-showcommand2 => ['CALLBACK', undef, undef, undef],
	-usecache     => ['PASSIVE', undef, undef, 1],
        -cpan         => ['METHOD',  undef, undef, 0],
    );
}

sub cpan {
    my $w = shift;
    if (@_) {
	$w->{Show_CPAN} = $_[0];
	$w->Fill(-cpan => $w->{Show_CPAN}) if $w->Filled; # refill
    }
    $w->{Show_CPAN};
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

#XXXX!!!
if ($args{-cpan}) { $usecache = 0 }

    # fills %pods hash:
    pod_find(-categorized => 1, -usecache => $usecache, -cpan => $args{-cpan});

    my %category_seen;

    foreach (['perl',   'Perl language'],
	     ['pragma', 'Pragmata'],
	     ['mod',    'Modules'],
	     ['script', 'Scripts'],
	     keys %pods,
	    ) {
	my($category, $title) = (ref $_ ? @$_ : ($_, $_));
	next if $category_seen{$category};

	$w->add($category, -text => $title);

	my $hash = $pods{$category};
	foreach my $pod (sort keys %$hash) {
#XXX del???	    next if $pod =~ /\./;#XXX

	    my $treepath = "$category/$pod";
	    (my $title = $pod) =~ s|/|::|g;
	    $w->_add_parents($treepath);

	    my $loc = Tk::Pod::FindPods::module_location($hash->{$pod});
	    my $is = $w->{Style}{$loc};
	    my @entry_args = ($treepath,
			      -text => $title,
			      -data => _PodEntry->create($hash->{$pod}),
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

    if ($w->cget('-usecache') && !$Tk::Pod::FindPods::has_cache
	&& !$args{-cpan} # XXX
       ) {
	Tk::Pod::FindPods::WriteCache();
    }

    $w->{Filled}++;
}

sub Filled { shift->{Filled} }

sub _add_parents {
    my($w, $entry) = @_;
    (my $parent = $entry) =~ s|/[^/]*$||;
    return if $parent eq '';
    do{warn "$entry XXX";return} if $parent eq $entry;
    return if $w->info('exists', $parent);
    my @parent = split '/', $parent;
    my $title = join "::", @parent[1..$#parent];
    $w->_add_parents($parent);
    $w->add($parent, -text => $title,
	    ($w->{Style}{'folder'} ? (-style => $w->{Style}{'folder'}) : ()));
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
    if ($^O eq 'MSWin32') {
	$path =~ s/\\/\//g;
	$path = lc $path;
    }
    DEBUG and warn "Call SeePath with $path\n";
    return if !$w->Filled; # XXX better solution!
    foreach my $category (keys %pods) {
	foreach my $pod (keys %{ $pods{$category} }) {
	    my $podpath = $pods{$category}->{$pod};
	    $podpath = lc $podpath if $^O eq 'MSWin32'; # XXX should be really File::Spec->is_case_tolerant
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
    DEBUG and warn "SeePath: cannot find $path in tree\n";
    0;
}

sub search_dialog {
    my($w) = @_;
    my $t = $w->Toplevel(-title => "Search");
    $t->transient($w);
    $t->Label(-text => "Search module:")->pack(-side => "left");
    my $term;
    my $e = $t->Entry(-textvariable => \$term)->pack(-side => "left");
    $e->focus;
    $e->bind("<Escape>" => sub { $t->destroy });
    $e->bind("<Return>" => sub { $w->search($term) });

    {
	my $f = $t->Frame->pack(-fill => "x");
	Tk::grid($f->Button(-text => "Search",
			    -command => sub { $w->search($term) },
			   ),
		 $f->Button(-text => "Close",
			    -command => sub { $t->destroy },
			   ),
		 -sticky => "ew");
    }
}

sub search {
    my($w, $rx) = @_;
    return if $rx eq '';
    my($entry) = ($w->info('selection'))[0];
    if (!defined $entry) {
	$entry = ($w->info('children'))[0];
	return if (!defined $entry);
    }
    my $wrapped = 0;
    while(1) {
	$entry = $w->info('next', $entry);
	if (!defined $entry) {
	    if ($wrapped) {
		$w->bell;
		return;
	    }
	    $wrapped++;
	    $entry = ($w->info('children'))[0];
	}
	my $text = $w->entrycget($entry, '-text');
	if ($text =~ /$rx/i) {
	    my $p = $entry;
	    while(1) {
		$p = $w->info('parent', $p);
		if (defined $p) {
		    $w->open($p);
		} else {
		    last;
		}
	    }
	    $w->selectionClear;
	    $w->selectionSet($entry);
	    $w->anchorSet($entry);
	    $w->see($entry);
	    return;
	}
    }
}

1;

__END__

=back

=head1 SEE ALSO

Tk::Tree(3), Tk::Pod(3), tkpod(1), Tk::Pod::FindPods(3).

=head1 AUTHOR

Slaven Rezic <F<slaven@rezic.de>>

Copyright (c) 2001 Slaven Rezic.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
