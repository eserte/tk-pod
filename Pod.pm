package Tk::Pod;
use strict;
use Tk ();
use Tk::Toplevel;

use vars qw($VERSION $DIST_VERSION @ISA);
$VERSION = substr(q$Revision: 2.30 $, 10) + 2 . "";
$DIST_VERSION = "0.9925";

@ISA = qw(Tk::Toplevel);

Construct Tk::Widget 'Pod';

my $openpod_history;
my $searchfaq_history;

sub Populate
{
 my ($w,$args) = @_;

 require Tk::Pod::Text;
 require Tk::Pod::Tree;

 $w->SUPER::Populate($args);

 my $tree = $w->Scrolled('PodTree',
			 -scrollbars => 'oso'.($Tk::platform eq 'MSWin32'?'e':'w')
			);
 $w->Advertise('tree' => $tree);

 my $searchcase = 0;
 my $p = $w->Component('PodText' => 'pod', -searchcase => $searchcase)->pack(-expand => 1, -fill => 'both');

 my $exitbutton = delete $args->{-exitbutton} || 0;

 my $menuitems =
 [

  [Cascade => '~File', -menuitems =>
   [
    [Button => '~Open File...', '-command' => ['openfile',$w]],
    [Button => 'Open ~by Name...', '-command' => ['openpod',$w,$p]],
    [Button => '~New Window...', '-command' => ['newwindow',$w,$p]],
    [Button => '~Reload',    '-command' => ['reload',$p]],
    [Button => '~Edit',      '-command' => ['edit',$p]],
    [Button => 'Edit with p~tked', '-command' => ['edit',$p,'ptked']],
    [Button => '~Print'. ($p->PrintHasDialog ? '...' : ''),  '-command' => ['Print',$p]],
    [Separator => ""],
    [Button => '~Close',     '-command' => ['quit',$w]],
    ($exitbutton
     ? [Button => 'E~xit',      '-command' => sub { $p->MainWindow->destroy }]
     : ()
    ),
   ]
  ],

  [Cascade => '~View', -menuitems =>
   [
    [Checkbutton => '~Pod Tree', -variable => \$w->{Tree_on},
     '-command' => sub { $w->tree($w->{Tree_on}) }],
    '-',
    [Button => "Zoom ~in",  '-accelerator' => 'Ctrl++', -command => ['zoom_in', $p]],
    [Button => "~Normal",   -command => ['zoom_normal', $p]],
    [Button => "Zoom ~out", '-accelerator' => 'Ctrl+-', -command => ['zoom_out', $p]],
   ]
  ],

  [Cascade => '~Search', -menuitems =>
   [
    [Button => '~Search',           '-accelerator' => '/', '-command' => ['Search', $p, 'Next']],
    [Button => 'Search ~backwards', '-accelerator' => '?', '-command' => ['Search', $p, 'Prev']],
    [Button => '~Repeat search',    '-accelerator' => 'n', '-command' => ['ShowMatch', $p, 'Next']],
    [Button => 'R~epeat backwards', '-accelerator' => 'N', '-command' => ['ShowMatch', $p, 'Prev']],
    [Checkbutton => '~Case sensitive', -variable => \$searchcase, '-command' => sub { $p->configure(-searchcase => $searchcase) }],
    [Separator => ""],
    [Button => 'Search ~full text', '-command' => ['SearchFullText', $p]],
    [Button => 'Search FA~Q', '-command' => ['SearchFAQ', $w, $p]],
   ]
  ],

  [Cascade => 'H~istory', -menuitems =>
   [
    [Button => '~Back',    '-accelerator' => 'Alt-Left',  '-command' => ['history_move', $p, -1]],
    [Button => '~Forward', '-accelerator' => 'Alt-Right', '-command' => ['history_move', $p, +1]],
    [Button => '~View',    '-command' => ['history_view', $p]],
    '-',
    [Button => 'Clear cache', '-command' => ['clear_cache', $p]],
   ]
  ],

  [Cascade => '~Help', -menuitems =>
   [
    # XXX restructure to not reference to tkpod
    [Button => '~Usage...',       -command => ['help', $w]],
    [Button => '~Programming...', -command => sub { $w->parent->Pod(-file=>'Tk/Pod.pm', -exitbutton => $w->cget(-exitbutton)) }],
    [Button => '~About...', -command => ['about', $w]],
   ]
  ]
 ];

 my $mbar = $w->Menu(-menuitems => $menuitems);
 $w->configure(-menu => $mbar);
 $w->Advertise(menubar => $mbar);

 $w->Delegates('Menubar' => $mbar);
 $w->ConfigSpecs(
    -tree => ['METHOD', 'tree', 'Tree', 0],
    -exitbutton => ['PASSIVE', 'exitButton', 'ExitButton', $exitbutton],
    'DEFAULT' => [$p],
 );

 foreach my $mod (qw(Alt Meta))
  {
   $w->bind($w->toplevel->PathName, "<$mod-Left>"  => [$p, 'history_move', -1]);
   $w->bind($w->toplevel->PathName, "<$mod-Right>" => [$p, 'history_move', +1]);
  }

 $w->bind($w->toplevel->PathName, "<Control-minus>" => [$p, 'zoom_out']);
 $w->bind($w->toplevel->PathName, "<Control-plus>" => [$p, 'zoom_in']);

 $w->protocol('WM_DELETE_WINDOW',['quit',$w]);
}

my $fsbox;

sub openfile {
    my ($cw,$p) = @_;
    my $file;
    if ($cw->can("getOpenFile")) {
	$file = $cw->getOpenFile
	    (-title => "Choose Pod file",
	     -filetypes => [['Pod containing files', ['*.pod',
						      '*.pl',
						      '*.pm']],
			    ['Pod files', '*.pod'],
			    ['Perl scripts', '*.pl'],
			    ['Perl modules', '*.pm'],
			    ['All files', '*']]);
    } else {
	unless (defined $fsbox && $fsbox->IsWidget) {
	    require Tk::FileSelect;
	    $fsbox = $cw->FileSelect();
	}
	$file = $fsbox->Show();
    }
    $cw->configure(-file => $file) if defined $file && -r $file;
}

sub openpod {
    my($cw,$p) = @_;
    my $t = $cw->Toplevel(-title => "Open Pod by Name");
    $t->transient($cw);
    $t->grab;
    my($pod, $e, $go);
    {
	my $Entry = 'Entry';
	eval {
	    require Tk::HistEntry;
	    Tk::HistEntry->VERSION(0.40);
	    $Entry = "HistEntry";
	};

	my $f = $t->Frame->pack(-fill => "x");
	$f->Label(-text => "Pod:")->pack(-side => "left");
	$e = $f->$Entry(-textvariable => \$pod)->pack(-side => "left", -fill => "x", -expand => 1);
	if ($e->can('history') && $openpod_history) {
	    $e->history($openpod_history);
	}
	$e->focus;
	$go = 0;
	$e->bind("<Return>" => sub { $go = 1 });
	$e->bind("<Escape>" => sub { $go = -1 });
    }

    {
	my $f = $t->Frame->pack;
	$f->Button(-text => "OK",
		   -command => sub { $go = 1 })->pack(-side => "left");
	$f->Button(-text => "New window",
		   -command => sub { $go = 2 })->pack(-side => "left");
	$f->Button(-text => "Cancel",
		   -command => sub { $go = -1 })->pack(-side => "left");
    }
    $t->Popup(-popover => $cw);
    $t->OnDestroy(sub { $go = -1 unless $go });
    $t->waitVariable(\$go);
    if (Tk::Exists($t)) {
	if ($pod ne "" && $go > 0 && $e->can('historyAdd')) {
	    $e->historyAdd($pod);
	    $searchfaq_history = [ $e->history ];
	}
	$t->grabRelease;
	$t->destroy;
    }
    if ($pod ne "") {
	if ($go == 1) {
	    $cw->configure(-file => $pod);
	} elsif ($go == 2) {
	    my $new_cw = $cw->MainWindow->Pod
		('-tree' => $cw->cget(-tree),
		 -exitbutton => $cw->cget(-exitbutton),
		);
	    $new_cw->configure('-file' => $pod);
	}
    }
}

sub newwindow {
    my($cw) = @_;
    $cw->MainWindow->Pod('-tree' => $cw->cget(-tree),
			 -exitbutton => $cw->cget(-exitbutton),
			);
}

sub Dir {
    require Tk::Pod::Text;
    require Tk::Pod::Tree;
    Tk::Pod::Text::Dir(@_);
    Tk::Pod::Tree::Dir(@_);
}


sub quit { shift->destroy }

sub help {
    my $w = shift;
    $w->parent->Pod(-file=>'Tk::Pod_usage.pod',
		    -exitbutton => $w->cget(-exitbutton),
		   );
}

sub about {
    my $message = <<EOF;
Tk-Pod distribution $DIST_VERSION
Tk::Pod module $VERSION
(Using Tk $Tk::VERSION@{[ $Pod::Simple::VERSION
			  ? " and Pod::Simple $Pod::Simple::VERSION"
			  : ""
			]}
on $^O)
Please contact <slaven\@rezic.de>
in case of problems.
EOF
    $_[0]->messageBox(-title   => "About Tk::Pod",
                      -icon    => "info",
		      -message => $message,
		     );
}

sub add_section_menu {
    my($pod) = @_;

    my $screenheight = $pod->screenheight;
    my $mbar = $pod->Subwidget('menubar');
    my $sectionmenu = $mbar->Subwidget('sectionmenu');
    if (defined $sectionmenu) {
        $sectionmenu->delete(0, 'end');
    } else {
	$mbar->insert($mbar->index("last"), "cascade",
		      '-label' => 'Section', -underline => 1);
	$sectionmenu = $mbar->Menu;
	$mbar->entryconfigure($mbar->index("last")-1, -menu => $sectionmenu);
	$mbar->Advertise(sectionmenu => $sectionmenu);
    }

    my $podtext = $pod->Subwidget('pod');
    my $text    = $podtext->Subwidget('more')->Subwidget('text');

    $text->tag('configure', '_section_mark',
               -background => 'red',
               -foreground => 'black',
              );

    my $sdef;
    foreach $sdef (@{$podtext->{'sections'}}) {
        my($head_level, $subject, $pos) = @$sdef;

	my @args;
	if ($sectionmenu &&
	    $sectionmenu->yposition("last") > $screenheight-40) {
	    push @args, -columnbreak => 1;
	}

        $sectionmenu->command
	  (-label => ("  " x ($head_level-1)) . $subject,
	   -command => sub {
	       my($line) = split(/\./, $pos);
	       $text->tag('remove', '_section_mark', qw/0.0 end/);
	       $text->tag('add', '_section_mark',
			  $line-1 . ".0",
			  $line-1 . ".0 lineend");
	       $text->yview("_section_mark.first");
	       $text->after(500, [$text, qw/tag remove _section_mark 0.0 end/]);
	   },
	   @args,
	  );
    }
}

sub tree {
    my $w = shift;
    if (@_) {
	my $val = shift;
	$w->{Tree_on} = $val;
	my $tree = $w->Subwidget('tree');
	my $p = $w->Subwidget("pod");
	if ($val) {
	    $p->packForget;
	    $tree->packAdjust(-side => 'left', -fill => 'y');
	    $p->pack(-side => "left", -expand => 1, -fill => 'both');
	    if (!$tree->Filled) {
		$w->_configure_tree;
		$w->Busy(-recurse => 1);
		eval {
		    $tree->Fill;
		};
		my $err = $@;
		$w->Unbusy;
		if ($err) {
		    die $err;
		}
	    }
	    $tree->SeePath("file:" . $p->cget(-path)) if $p->cget(-path);
	} else {
	    if ($tree && $tree->manager) {
		$tree->packForget;
		$p->packForget;
		eval {
		    $w->Walk
			(sub {
			     my $w = shift;
			     if ($w->isa('Tk::Adjuster') &&
				 $w->cget(-widget) eq $tree) {
				 $w->destroy;
				 die;
			     }
			 });
		};
		$p->pack(-side => "left", -expand => 1, -fill => 'both');
	    }
	}
    }
    $w->{Tree_on};
}

sub _configure_tree {
    my($w) = @_;
    my $tree = $w->Subwidget("tree");
    my $p    = $w->Subwidget("pod");

    my $common_showcommand = sub {
	my($e) = @_;
	my $uri = $e->uri;
	my $type = $e->type;
	if (defined $type && $type eq 'func') {
	    my $text = $Tk::Pod::Tree::FindPods->function_pod($e->name);
	    (-text => $text, -title => $e->name);
	} elsif (defined $uri && $uri =~ /^file:(.*)/) {
	    (-file => $1);
	} else {
	    # ignore
	}
    };

    $tree->configure
	(-showcommand  => sub {
	     my $e = $_[1];
	     my %args = $common_showcommand->($e);
	     my $title = delete $args{-title};
	     $p->configure(-title => $title) if defined $title;
	     $p->configure(%args);
	 },
	 -showcommand2 => sub {
	     my $e = $_[1];
	     my @args = $common_showcommand->($e);
	     # XXX -title?
	     $w->MainWindow->Pod
		 (@args,
		  '-exitbutton' => $w->cget(-exitbutton),
		  '-tree' => !!$tree,
		 );
	 },
	);
}

sub SearchFAQ {
    my($cw, $p) = @_;
    my $t = $cw->Toplevel(-title => "Perl FAQ Search");
    $t->transient($cw);
    $t->grab;
    my($keyword, $go, $e);
    {
	my $f = $t->Frame->pack(-fill => "x");
	$f->Label(-text => "FAQ keyword:")->pack(-side => "left");
	$e = $f->Entry(-textvariable => \$keyword)->pack(-side => "left");
	if ($e->can('history') && $searchfaq_history) {
	    $e->history($searchfaq_history);
	}
	$e->focus;
	$go = 0;
	$e->bind("<Return>" => sub { $go = 1 });
	$e->bind("<Escape>" => sub { $go = -1 });
    }
    {
	my $f = $t->Frame->pack;
	$f->Button(-text => "OK",
		   -command => sub { $go = 1 })->pack(-side => "left");
	$f->Button(-text => "New window",
		   -command => sub { $go = 2 })->pack(-side => "left");
	$f->Button(-text => "Cancel",
		   -command => sub { $go = -1 })->pack(-side => "left");
    }
    $t->Popup(-popover => $cw);
    $t->OnDestroy(sub { $go = -1 unless $go });
    $t->waitVariable(\$go);
    if (Tk::Exists($t)) {
	if ($keyword ne "" && $go > 0 && $e->can('historyAdd')) {
	    $e->historyAdd($keyword);
	    $searchfaq_history = [ $e->history ];
	}
	$t->grabRelease;
	$t->destroy;
    }
    if ($keyword ne "") {
	if ($go) {
	    require File::Temp;
	    my($fh, $pod) = File::Temp::tempfile(UNLINK => 1,
						 SUFFIX => ".pod");
	    my $out = `perldoc -u -q $keyword`; # XXX protect keyword
	    print $fh $out;
	    close $fh;

	    if ($go == 1) {
		$cw->configure(-file => $pod);
	    } elsif ($go == 2) {
		my $new_cw = $cw->MainWindow->Pod
		    ('-tree' => $cw->cget('-tree'),
		     '-exitbutton' => $cw->cget('-exitbutton'),
		    );
		$new_cw->configure('-file' => $pod);
	    }
	}
    }
}

1;

__END__

=head1 NAME

Tk::Pod - Pod browser toplevel widget


=head1 SYNOPSIS

    use Tk::Pod

    Tk::Pod->Dir(@dirs)			# add dirs to search path for Pod

    $pod = $parent->Pod(
		-file = > $name,	# search and display Pod for name
		-tree = > $bool		# display pod file tree
		);


=head1 DESCRIPTION

Simple Pod browser with hypertext capabilities in a C<Toplevel> widget

=head1 OPTIONS

=over

=item -tree

Set tree view by default on or off. Default is false.

=item -exitbutton

Add to the menu an exit entry. This is only useful for standalone pod
readers. Default is false. This option can only be set on construction
time.

=back

Other options are propagated to the embedded L<Tk::Pod::Text> widget.

=head1 BUGS

If you set C<-file> while creating the Pod widget,

    $parent->Pod(-tree => 1, -file => $pod);

then the title will not be displayed correctly. This is because the
internal setting of C<-title> may override the title setting caused by
C<-file>. So it is better to configure C<-file> separately:

    $pod = $parent->Pod(-tree => 1);
    $pod->configure(-file => $pod);

=head1 SEE ALSO

L<Tk::Pod_usage|Tk::Pod_usage>
L<Tk::Pod::Text|Tk::Pod::Text>
L<tkpod|tkpod>
L<perlpod|perlpod>

=head1 AUTHOR

Nick Ing-Simmons <F<nick@ni-s.u-net.com>>

Current maintainer is Slaven Rezic <F<slaven@rezic.de>>.

Copyright (c) 1997-1998 Nick Ing-Simmons.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

