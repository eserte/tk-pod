package Tk::Pod;
use strict;
use Tk ();
use Tk::Toplevel;

use vars qw($VERSION $DIST_VERSION @ISA);
$VERSION = substr(q$Revision: 2.34 $, 10) + 2 . "";
$DIST_VERSION = "0.9927";

@ISA = qw(Tk::Toplevel);

Construct Tk::Widget 'Pod';

my $openpod_history;
my $searchfaq_history;

sub Pod_Text_Widget { "PodText" }
sub Pod_Text_Module { "Tk::Pod::Text" }

sub Pod_Tree_Widget { "PodTree" }
sub Pod_Tree_Module { "Tk::Pod::Tree" }

sub Populate
{
 my ($w,$args) = @_;

 if ($w->Pod_Text_Module)
  {
   eval q{ require } . $w->Pod_Text_Module;
   die $@ if $@;
  }
 if ($w->Pod_Tree_Module)
  {
   eval q{ require } . $w->Pod_Tree_Module;
   die $@ if $@;
  }

 $w->SUPER::Populate($args);

 my $tree = $w->Scrolled($w->Pod_Tree_Widget,
			 -scrollbars => 'oso'.($Tk::platform eq 'MSWin32'?'e':'w')
			);
 $w->Advertise('tree' => $tree);

 my $searchcase = 0;
 my $p = $w->Component($w->Pod_Text_Widget => 'pod', -searchcase => $searchcase)->pack(-expand => 1, -fill => 'both');

 my $exitbutton = delete $args->{-exitbutton} || 0;

 # Experimental menu compound images:
 # XXX Maybe there should be a way to turn this off, as the extra
 # icons might be memory consuming...
 my $compound = sub { () };
 if ($Tk::VERSION >= 804 && eval { require Tk::ToolBar; 1 }) {
     $w->ToolBar->destroy;
     if (!$Tk::Pod::empty_image_16) { # XXX multiple MainWindows?
	 $Tk::Pod::empty_image_16 = $w->MainWindow->Photo(-data => <<EOF);
R0lGODlhEAAQAIAAAP///////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAh+QQBCgABACwA
AAAAEAAQAAACDoyPqcvtD6OctNqLsz4FADs=
EOF
     }
     $compound = sub {
	 if (@_) {
	     (-image => $_[0] . "16", -compound => "left");
	 } else {
	     (-image => $Tk::Pod::empty_image_16, -compound => "left");
	 }
     };
 }

 my $menuitems =
 [

  [Cascade => '~File', -menuitems =>
   [
    [Button => '~Open File...', '-accelerator' => 'F3',
     '-command' => ['openfile',$w],
     $compound->("fileopen"),
    ],
    [Button => 'Open ~by Name...', '-accelerator' => 'Ctrl+O',
     '-command' => ['openpod',$w,$p],
     $compound->(),
    ],
    [Button => '~New Window...', '-accelerator' => 'Ctrl+N',
     '-command' => ['newwindow',$w,$p],
     $compound->(),
    ],
    [Button => '~Reload',    '-accelerator' => 'Ctrl+R',
     '-command' => ['reload',$p],
     $compound->("actreload"),
    ],
    [Button => '~Edit',      '-command' => ['edit',$p],
     $compound->("edit"),
    ],
    [Button => 'Edit with p~tked', '-command' => ['edit',$p,'ptked'],
     $compound->(),
    ],
    [Button => '~Print'. ($p->PrintHasDialog ? '...' : ''),
     '-accelerator' => 'Ctrl+P', '-command' => ['Print',$p],
     $compound->("fileprint"),
    ],
    [Separator => ""],
    [Button => '~Close',     '-accelerator' => 'Ctrl+W',
     '-command' => ['quit',$w],
     $compound->("fileclose"),
    ],
    ($exitbutton
     ? [Button => 'E~xit',   '-accelerator' => 'Ctrl+Q',
	'-command' => sub { $p->MainWindow->destroy },
	$compound->("actexit"),
       ]
     : ()
    ),
   ]
  ],

  [Cascade => '~View', -menuitems =>
   [
    [Checkbutton => '~Pod Tree', -variable => \$w->{Tree_on},
     '-command' => sub { $w->tree($w->{Tree_on}) },
     $compound->(),
    ],
    '-',
    [Button => "Zoom ~in",  '-accelerator' => 'Ctrl++',
     -command => ['zoom_in', $p],
     $compound->("viewmag+"),
    ],
    [Button => "~Normal",   -command => ['zoom_normal', $p],
     $compound->(),
    ],
    [Button => "Zoom ~out", '-accelerator' => 'Ctrl+-',
     -command => ['zoom_out', $p],
     $compound->("viewmag-"),
    ],
   ]
  ],

  [Cascade => '~Search', -menuitems =>
   [
    [Button => '~Search',
     '-accelerator' => '/', '-command' => ['Search', $p, 'Next'],
     $compound->("viewmag"),
    ],
    [Button => 'Search ~backwards',
     '-accelerator' => '?', '-command' => ['Search', $p, 'Prev'],
     $compound->(),
    ],
    [Button => '~Repeat search',
     '-accelerator' => 'n', '-command' => ['ShowMatch', $p, 'Next'],
     $compound->(),
    ],
    [Button => 'R~epeat backwards',
     '-accelerator' => 'N', '-command' => ['ShowMatch', $p, 'Prev'],
     $compound->(),
    ],
    [Checkbutton => '~Case sensitive', -variable => \$searchcase,
     '-command' => sub { $p->configure(-searchcase => $searchcase) },
     $compound->(),
    ],
    [Separator => ""],
    [Button => 'Search ~full text', '-command' => ['SearchFullText', $p],
     $compound->("filefind"),
    ],
    [Button => 'Search FA~Q', '-command' => ['SearchFAQ', $w, $p],
     $compound->(),
    ],
   ]
  ],

  [Cascade => 'H~istory', -menuitems =>
   [
    [Button => '~Back',    '-accelerator' => 'Alt-Left',
     '-command' => ['history_move', $p, -1],
     $compound->("navback"),
    ],
    [Button => '~Forward', '-accelerator' => 'Alt-Right',
     '-command' => ['history_move', $p, +1],
     $compound->("navforward"),
    ],
    [Button => '~View',    '-command' => ['history_view', $p],
     $compound->(),
    ],
    '-',
    [Button => 'Clear cache', '-command' => ['clear_cache', $p],
     $compound->(),
    ],
   ]
  ],

  [Cascade => '~Help', -menuitems =>
   [
    # XXX restructure to not reference to tkpod
    [Button => '~Usage...',       -command => ['help', $w]],
    [Button => '~Programming...', -command => sub { $w->parent->Pod(-file=>'Tk/Pod.pm', -exitbutton => $w->cget(-exitbutton)) }],
    [Button => '~About...', -command => ['about', $w]],
    ($ENV{'TKPODDEBUG'}
     ? ('-',
	[Button => 'WidgetDump', -command => sub { $w->WidgetDump }],
       )
     : ()
    ),
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
    -background => ['PASSIVE'], # XXX see comment in Tk::More
    -cursor => ['CHILDREN'],
    'DEFAULT' => [$p],
 );

 {
  my $path = $w->toplevel->PathName;
  foreach my $mod (qw(Alt Meta))
   {
    $w->bind($path, "<$mod-Left>"  => [$p, 'history_move', -1]);
    $w->bind($path, "<$mod-Right>" => [$p, 'history_move', +1]);
   }

  $w->bind($path, "<Control-minus>" => [$p, 'zoom_out']);
  $w->bind($path, "<Control-plus>" => [$p, 'zoom_in']);
  $w->bind($path, "<F3>" => [$w,'openfile']);
  $w->bind($path, "<Control-o>" => [$w,'openpod',$p]);
  $w->bind($path, "<Control-n>" => [$w,'newwindow',$p]);
  $w->bind($path, "<Control-r>" => [$p, 'reload']);
  $w->bind($path, "<Control-p>" => [$p, 'Print']);
  $w->bind($path, "<Control-w>" => [$w, 'quit']);
  $w->bind($path, "<Control-q>" => sub { $p->MainWindow->destroy })
      if $exitbutton;
 }

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
	Tk::grid($f->Label(-text => "Use 'Module::Name' for module documentation"), -sticky => "w");
	Tk::grid($f->Label(-text => "Use '-f function' for function documentation"), -sticky => "w");
	Tk::grid($f->Label(-text => "Use '-q terms' for FAQ entries"), -sticky => "w");
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
	if (defined $pod && $pod ne "" && $go > 0 && $e->can('historyAdd')) {
	    $e->historyAdd($pod);
	    $openpod_history = [ $e->history ];
	}
	$t->grabRelease;
	$t->destroy;
    }

    my %pod_args = ('-file' => $pod);
    if (defined $pod && $pod =~ /^-(f|q)\s+(.+)/) {
	my $switch = $1;
	my $func = $2;
	my $func_pod = "";
	open(FUNCPOD, "-|") or do {
	    exec "perldoc", "-u", "-$switch", $func;
	    warn "Can't execute perldoc: $!";
	    CORE::exit(1);
	};
	local $/ = undef;
	$func_pod = join "", <FUNCPOD>;
	close FUNCPOD;
	if ($func_pod ne "") {
	    delete $pod_args{'-file'};
	    $pod_args{'-text'}  = $func_pod;
	    if ($switch eq "f") {
		$pod_args{'-title'} = "Function $func";
	    } else {
		$pod_args{'-title'} = "FAQ $func";
	    }
	}
    }

    if (defined $pod && $pod ne "") {
	if ($go == 1) {
	    $cw->configure(%pod_args);
	} elsif ($go == 2) {
	    my $new_cw = $cw->MainWindow->Pod
		('-tree' => $cw->cget(-tree),
		 -exitbutton => $cw->cget(-exitbutton),
		);
	    $new_cw->configure(%pod_args);
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
This is:
Tk-Pod distribution $DIST_VERSION
Tk::Pod module $VERSION

Using:
@{[ $Pod::Simple::VERSION ? "Pod::Simple $Pod::Simple::VERSION\n"
			  : ""
]}Tk $Tk::VERSION
Perl $]
OS $^O

Please contact <srezic\@cpan.org>
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
	my $Entry = 'Entry';
	eval {
	    require Tk::HistEntry;
	    Tk::HistEntry->VERSION(0.40);
	    $Entry = "HistEntry";
	};

	my $f = $t->Frame->pack(-fill => "x");
	$f->Label(-text => "FAQ keyword:")->pack(-side => "left");
	$e = $f->$Entry(-textvariable => \$keyword)->pack(-side => "left");
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
	if (defined $keyword && $keyword ne "" && $go > 0 && $e->can('historyAdd')) {
	    $e->historyAdd($keyword);
	    $searchfaq_history = [ $e->history ];
	}
	$t->grabRelease;
	$t->destroy;
    }
    if (defined $keyword && $keyword ne "") {
	if ($go) {
	    require File::Temp;
	    my($fh, $pod) = File::Temp::tempfile(UNLINK => 1,
						 SUFFIX => ".pod");
	    my $out = `perldoc -u -q $keyword`; # XXX protect keyword
	    print $fh $out;
	    close $fh;

	    if (-z $pod) {
		$cw->messageBox(-title   => "No FAQ keyword",
				-icon    => "error",
				-message => "FAQ keyword not found",
			       );
	    } else {
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

