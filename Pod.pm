package Tk::Pod;
use strict;
use Tk ();
use Tk::Toplevel;

use vars qw($VERSION @ISA);
$VERSION = substr(q$Revision: 1.2 $, 10) + 2 . "";

@ISA = qw(Tk::Toplevel);

Construct Tk::Widget 'Pod';

sub Populate
{
 my ($w,$args) = @_;

 require Tk::Pod::Text;
 require Tk::Pod::Tree;
 require Tk::Menubar;

 $w->SUPER::Populate($args);

 my $tree;

 if (delete $args->{-tree}) {
     $tree= $w->Scrolled('PodTree', -scrollbars => 'oso'.$Tk::platform eq 'MSWin32'?'e':'w')->packAdjust(-side => "left", -fill => 'y');
     $w->Advertise(tree => $tree);
     $tree->Fill;
 }

 my $searchcase = 0;
 my $p = $w->Component('PodText' => 'pod', -searchcase => $searchcase)->pack(-expand => 1, -fill => 'both');

 $tree->configure(-showcommand => sub { $p->configure(-file => $_[1]->{File}) }) if $tree;

 my $mbar = $w->Component('Menubar' => 'menubar');
 my $file = $mbar->Component('Menubutton' => 'file', '-text' => 'File', '-underline' => 0);
 $file->command('-label'=>'Open...', '-underline'=>0, '-command' => ['openfile',$w]);
 $file->command('-label'=>'Re-Read', '-underline'=>0, '-command' => ['reload',$p] );
 $file->command('-label'=>'Edit',    '-underline'=>0, '-command' => ['edit',$p] );
 $file->command('-label'=>'Print',   '-underline'=>0, '-command' => ['Print',$p] );
 $file->separator;
 $file->command('-label'=>'Close',    '-underline'=>0, '-command' => ['quit',$w] );
 $file->command('-label'=>'Exit',     '-underline'=>1, '-command' => sub { Tk::exit } );

 my $search = $mbar->Component('Menubutton' => 'search', '-text' => 'Search', '-underline' => 0);
 $search->command('-label'=>'Search', '-underline'=>0, '-accelerator' => '/', '-command' => ['Search', $p, 'Next']);
 $search->command('-label'=>'Search backwards', '-underline'=>7, '-command' => ['Search', $p, 'Prev']);
 $search->command('-label'=>'Repeat search', '-underline'=>0, '-accelerator' => 'n', '-command' => ['ShowMatch', $p, 'Next']);
 $search->command('-label'=>'Repeat backwards', '-underline'=>1, '-accelerator' => 'N', '-command' => ['ShowMatch', $p, 'Prev']);
 $search->checkbutton('-label'=>'Case sensitive', '-underline'=>0, -variable => \$searchcase, '-command' => sub { $p->configure(-searchcase => $searchcase) });
 $search->separator;
 $search->command('-label'=>'Search full text', '-underline'=>7, '-command' => ['SearchFullText', $p, 'Prev']);

 my $history = $mbar->Component('Menubutton' => 'History', '-text' => 'History', '-underline' => 1);
 $history->command('-label'=>'Back', '-underline'=>0, '-accelerator' => 'Alt-Left', '-command' => ['history_move', $p, -1]);
 $history->command('-label'=>'Forward', '-underline'=>0,  '-accelerator' => 'Alt-Right', '-command' => ['history_move', $p, +1]);
 $history->command('-label'=>'View', '-underline'=>0,  '-command' => ['history_view', $p]);

 my $help = $mbar->Component('Menubutton' => 'help', -side=>'right', '-text' => 'Help', '-underline' => 0);
 # xxx restructure to not reference to tkpod
 $help->command('-label' => 'Usage...', -command => sub{
		$w->parent->Pod(-file=>'Tk::Pod_usage.pod')
		});
 $help->command('-label' => 'Programming...', 
		-command => sub{$w->parent->Pod(-file=>'Tk/Pod.pm')} );

  {
     my $tkversion = $Tk::VERSION;
     $tkversion =~ s/_//g;	# so 800.0_01 < 800.002
     if ($tkversion lt '800.000')
       {
          $help->pack('-side'=>'right','-anchor'=>'e');
          $file->pack('-side'=>'left','-anchor'=>'w');
          $mbar->pack('-side'=>'top', '-fill'=>'x', '-before'=>($w->packSlaves)[0]);
       }
  }
 $w->Delegates('Menubutton' => $mbar, DEFAULT => $p);
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
    Tk::Pod::Text::Dir(@_);
    Tk::Pod::Tree::Dir(@_);
}


sub quit { shift->destroy }

sub add_section_menu {
    my($pod) = @_;
    my $mbar = $pod->Subwidget('menubar');
    my $section = $mbar->Subwidget('section');
    if (defined $section) {
        $section->cget(-menu)->delete(0, 'end');
    } else {
        $section = $mbar->Component('Menubutton' => 'section',
                                    '-text' => 'Section',
                                    -underline => 1);
    }
    my $podtext = $pod->Subwidget('pod');
    my $text    = $podtext->Subwidget('more')->Subwidget('text');

    $text->tag('configure', '_section_mark',
               -background => 'red',
               -foreground => 'black',
              );

    my $sdef;
    foreach $sdef (@{$podtext->{'sections'}}) {
        my($head, $subject, $pos) = @$sdef;
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

Code currently maintained by Achim Bohnet <F<ach@mpe.mpg.de>>.
Please send bug reports to <F<ptk@lists.stanford.edu>>.

Copyright (c) 1997-1998 Nick Ing-Simmons.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

