package Tk::Pod;
use strict;
use Tk ();
use Tk::Toplevel;

use vars qw($VERSION @ISA);
$VERSION = substr(q$Revision: 2.2 $, 10) + 2 . "";

@ISA = qw(Tk::Toplevel);

Construct Tk::Widget 'Pod';

sub Populate
{
 my ($w,$args) = @_;

 require Tk::Pod::Text;

 $w->SUPER::Populate($args);

 my $tree;

 if (delete $args->{-tree}) {
     require Tk::Pod::Tree;
     $tree = $w->Scrolled('PodTree', -scrollbars => 'oso'.($Tk::platform eq 'MSWin32'?'e':'w'))->packAdjust(-side => "left", -fill => 'y');
     $w->Advertise(tree => $tree);
     $tree->Fill;
 }

 my $searchcase = 0;
 my $p = $w->Component('PodText' => 'pod', -searchcase => $searchcase)->pack(-expand => 1, -fill => 'both');

 if ($tree) {
     $tree->configure
	 (-showcommand  => sub { $p->configure(-file => $_[1]->{File}) },
	  -showcommand2 => sub { $w->MainWindow->Pod('-file' => $_[1]->{File},
						     '-tree' => !!$tree)
			     },
	 );
 }

 my $menuitems =
 [

  [Cascade => '~File', -menuitems =>
   [
    [Button => '~Open...',   '-command' => ['openfile',$w]],
    [Button => '~Reload',    '-command' => ['reload',$p]],
    [Button => '~Edit',      '-command' => ['edit',$p]],
    [Button => 'Edit with p~tked', '-command' => ['edit',$p,'ptked']],
    [Button => '~Print...',  '-command' => ['Print',$p]],
    [Separator => ""],
    [Button => '~Close',     '-command' => ['quit',$w]],
    [Button => 'E~xit',      '-command' => sub { Tk::exit }],
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
   ]
  ],

  [Cascade => '~Help', -menuitems =>
   [
    # XXX restructure to not reference to tkpod
    [Button => '~Usage...',       -command => ['help', $w]],
    [Button => '~Programming...', -command => sub { $w->parent->Pod(-file=>'Tk/Pod.pm') }],
   ]
  ]
 ];

 my $mbar = $w->Menu(-menuitems => $menuitems);
 $w->configure(-menu => $mbar);
 $w->Advertise(menubar => $mbar);

 $w->Delegates('Menubar' => $mbar, DEFAULT => $p);
 $w->Delegates(DEFAULT => $p);
 $w->ConfigSpecs(
    -tree => ['PASSIVE', undef, undef, !!$tree], # XXX better solution
    'DEFAULT' => [$p],
 );

 $w->bind('<Alt-Left>'  => [$p, 'history_move', -1]);
 $w->bind('<Alt-Right>' => [$p, 'history_move', +1]);

 # $w->process($path);
 $w->protocol('WM_DELETE_WINDOW',['quit',$w]);
}

my $fsbox;

sub openfile {
    my ($cw,$p) = @_;
    my $file;
    if ($cw->can("getOpenFile")) {
	$file = $cw->getOpenFile(-title => "Choose POD file",
				 -defaultextension => 'pod',
				 -filetypes => [['POD files', '*.pod'],
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

sub Dir {
    require Tk::Pod::Text;
    require Tk::Pod::Tree;
    Tk::Pod::Text::Dir(@_);
    Tk::Pod::Tree::Dir(@_);
}


sub quit { shift->destroy }

sub help {
    shift->parent->Pod(-file=>'Tk::Pod_usage.pod');
}

sub add_section_menu {
    my($pod) = @_;

    my $screenheight = $pod->screenheight;

    my $mbar = $pod->Subwidget('menubar');
    my $section = $mbar->Subwidget('section');
    if (defined $section) {
        $section->cget(-menu)->delete(0, 'end');
    } else {
        $section = $mbar->Component('Menubutton' => 'section',
                                    '-text' => 'Section',
                                    -underline => 1);
    }
    my $sectionmenu = $section->menu;
    my $podtext = $pod->Subwidget('pod');
    my $text    = $podtext->Subwidget('more')->Subwidget('text');

    $text->tag('configure', '_section_mark',
               -background => 'red',
               -foreground => 'black',
              );

    my $sdef;
    foreach $sdef (@{$podtext->{'sections'}}) {
        my($head, $subject, $pos) = @$sdef;

	# XXX is this necessary on Windows?
	my @args;
	if ($sectionmenu &&
	    $sectionmenu->yposition("last") > $screenheight-40) {
	    push @args, -columnbreak => 1;
	}

        $section->command
	  (-label => ("  " x ($head-1)) . $subject,
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

1;

__END__

=head1 NAME

Tk::Pod - POD browser toplevel widget


=head1 SYNOPSIS

    use Tk::Pod

    Tk::Pod->Dir(@dirs)			# add dirs to search path for POD

    $pod = $parent->Pod(
		-file = > $name,	# search and display POD for name
		-tree = > $bool		# display pod file tree
		);


=head1 DESCRIPTION

Simple POD browser with hypertext capabilities in a C<Toplevel> widget


=head1 SEE ALSO

L<Tk::Pod_usage|Tk::Pod_usage>
L<Tk::Pod::Text|Tk::Pod::Text>
L<tkpod|tkpod>
L<perlpod|perlpod>

=head1 AUTHOR

Nick Ing-Simmons <F<nick@ni-s.u-net.com>>

Code currently maintained by Slaven Rezic <F<slaven.rezic@berlin.de>>.

Copyright (c) 1997-1998 Nick Ing-Simmons.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

