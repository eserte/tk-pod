package Tk::Pod;
use strict;
use Tk ();
use Tk::Toplevel;

use vars qw($VERSION @ISA);
$VERSION = substr(q$Revision: 2.23 $, 10) + 2 . "";

@ISA = qw(Tk::Toplevel);

Construct Tk::Widget 'Pod';

my $openpod_history;

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
    [Button => '~Print...',  '-command' => ['Print',$p]],
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
    [Button => 'Search ~full text', '-command' => ['SearchFullText', $p, 'Prev']],
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

 $w->bind($w->toplevel->PathName, "<Control-minus>" => [$p, 'zoom_in']);
 $w->bind($w->toplevel->PathName, "<Control-plus>" => [$p, 'zoom_out']);

 $w->protocol('WM_DELETE_WINDOW',['quit',$w]);
}

my $fsbox;

sub openfile {
    my ($cw,$p) = @_;
    my $file;
    if ($cw->can("getOpenFile")) {
	$file = $cw->getOpenFile
	    (-title => "Choose Pod file",
	     -defaultextension => 'pod',
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
	    $openpod_history = [ $e->history ];
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
    shift->messageBox(-title => "About Tk::Pod",
                      -icon => "info",
		      -message => join "\n",
		        "Tk::Pod $VERSION",
		        $Pod::Simple::VERSION
		          ? "(Using Pod::Simple $Pod::Simple::VERSION)"
		          : (),
		        'Please contact <slaven@rezic.de>',
		        "in case of problems.",
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
    $tree->configure
	(-showcommand  => sub {
	     my $e = $_[1];
	     my $uri = $e->uri;
	     if ($uri =~ /^file:(.*)/) {
		 $p->configure(-file => $1);
	     } elsif ($uri =~ /^cpan:(.*)/) {
		 my $modid = $1;
		 # XXX nach ..../CPAN.pm auslagern

		 my $asked = 0;
		 my $ask = sub {
		     $asked++;
		     $w->messageBox
			 (-message => "Look into CPAN module $modid?",
			  -title => "Tk::Pod and CPAN $modid",
			  -type => 'YesNo',
			  -icon => 'question') =~ /yes/i
		      };
		 if ($w->{CPAN_Asked} || $ask->()) {
		     $w->{CPAN_Asked}++;
		     require CPAN;
		     my(@mods) = CPAN::Shell->expand("Module", $modid);
		     if (@mods != 1) {
			 die "Found more/less than 1 module for $modid: @mods";
		     }
		     my $mod = shift @mods;
		     my $dist = $CPAN::META->instance('CPAN::Distribution', $mod->cpan_file);

		     require ExtUtils::MakeMaker;
		     my($local_wanted) =
			 MM->catfile(
				     $CPAN::Config->{keep_source_where},
				     "authors",
				     "id",
				     split("/",$dist->id)
				    );
		     if ($asked || -e $local_wanted || $ask->()) {
			 my $dir  = $dist->dir or $dist->get;
			 $dir = $dist->dir;
			 eval { $mod->make }; # XXX Reihenfolge ist wichtig!!!
			 if ($@) { warn $@ }
			 (my $modpath = $modid) =~ s|::|/|g;
			 my $blib_modpath = "$dir/blib/lib/$modpath";
			 if (-r "$blib_modpath.pod") {
			     $modpath = "$blib_modpath.pod";
			 } elsif (-r "$blib_modpath.pm") {
			     $modpath = "$blib_modpath.pm";
			 } else {
			     # try to find it...
			     require File::Find;
			     require File::Basename;
			     my @hits;
			 TRY: {
				 foreach my $path ("$modpath.pod",
						   "$modpath.pm",
						   File::Basename::basename($modpath) . ".pod",
						   File::Basename::basename($modpath) . ".pm") {
				     File::Find::find
					     (sub {
						  rindex($File::Find::name, $path) == length($File::Find::name)-length($path)
						      &&
							  push @hits, $File::Find::name;
					      }, $dir);
				     if (@hits) {
					 warn "More than 1 hit: @hits" if @hits > 1;
					 $modpath = "$hits[0]"; #XXX is it really absolute?
					 last TRY;
				     }
				 }
				 die "Can't find $modpath";
			     }
			 }
			 $p->configure(-file => $modpath);
		     }
		 }
	     } else {
		 die "Unrecognized uri $uri";
	     }
	 },
	 -showcommand2 => sub {#XXX rewrite for CPAN...
	     my $e = $_[1];
	     my $uri = $e->uri;
	     if ($uri =~ /^file:(.*)/) {
		 $w->MainWindow->Pod
		     ('-file' => $1,
		      -exitbutton => $w->cget(-exitbutton),
		      '-tree' => !!$tree);
	     } else {
		 die "NYI";
	     }
	 },
	);
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

