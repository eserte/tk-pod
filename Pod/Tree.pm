# -*- perl -*-

#
# $Id: Tree.pm,v 1.3 2001/06/16 15:17:49 eserte Exp $
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
use vars qw($VERSION @ISA @POD %pods $pods);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base 'Tk::Tree';

use Tk::Pod::FindPods;
use Tk::ItemStyle;

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

    $w->{CoreIS}   = $w->ItemStyle('imagetext', -foreground => '#006000');
    $w->{SiteIS}   = $w->ItemStyle('imagetext', -foreground => '#800000');
    $w->{FolderIS} = $w->ItemStyle('imagetext', -foreground => '#606060');

    $w->ConfigSpecs(
	-showcommand => ['CALLBACK', undef, undef, undef],
	-usecache    => ['PASSIVE', undef, undef, 1],
    );
}

sub Fill {
    my $w = shift;

    $w->delete("all");

    if ($w->cget('-usecache')) {
	$w->LoadCache;
    }

    if (!%pods) {
	%pods = Tk::Pod::FindPods::pod_find(-categorized => 1);
    }
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

    if ($w->cget('-usecache') && !$w->{HasCache}) {
	$w->WriteCache;
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

sub _cache_file {
    require File::Spec;

    (my $ver = $])  =~ s/[^a-z0-9]/_/gi;
    (my $os  = $^O) =~ s/[^a-z0-9]/_/gi;
    my $uid  = $<;

    File::Spec->catfile(File::Spec->tmpdir, join('_', 'tkpod',$ver,$os,$uid));
}

sub WriteCache {
    my $w = shift;

    if (!%pods) {
	%pods = Tk::Pod::FindPods::pod_find(-categorized => 1);
    }

    require Data::Dumper;

    if (!open(CACHE, ">" . $w->_cache_file)) {
	warn "Can't write to cache file " . $w->_cache_file;
    } else {
	my $dd = Data::Dumper->new([\%pods], ['pods']);
	$dd->Indent(0);
	print CACHE $dd->Dump;
	close CACHE;
    }
}

sub LoadCache {
    my $w = shift;

    my $cache_file = $w->_cache_file;
    if (-r $cache_file) {
	return if $< != (stat($cache_file))[4];
	require Safe;
	my $c = Safe->new;
	$c->share(qw/$pods/);
	$c->rdo($cache_file);
	if (keys %$pods) {
	    %pods = %$pods;
	    $w->{HasCache} = 1;
	}
    }
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
