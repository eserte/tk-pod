package Tk::More;

use strict;
use vars qw($VERSION @ISA);

$VERSION = substr(q$Revision: 2.2 $, 10) . "";

use Tk::Derived;
use Tk::Frame;
@ISA = qw(Tk::Derived Tk::Frame);

Construct Tk::Widget 'More';

sub Populate {
    my ($cw, $args) = @_;

    require Tk::ROText;
    require Tk::LabEntry;

    $cw->SUPER::Populate($args);

    my $Entry = 'LabEntry';
    my @Entry_args;
    if (eval { die "Not yet";
	       require Tk::HistEntry;
	       Tk::HistEntry->VERSION(0.37);
	       1;
	   }) {
	$Entry = 'HistEntry';
    } else {
	@Entry_args = (-labelPack=>[-side =>'left']);
    }

    my $search;
    my $e = $cw->$Entry(
		@Entry_args,
		-textvariable => \$search,
		-relief => 'flat',
		-state => 'disabled',
		)->pack(-side=>'bottom', -fill => 'x', -expand=>'no');
    $cw->Advertise('searchentry' => $e);

    my $t = $cw->ROText(-cursor=>undef)->pack(-fill => 'both' , -expand => 'yes');
    $cw->Advertise('text' => $t);
    $t->tagConfigure('search', -foreground => 'red');

    # reorder bindings: private widget bindings first
    $t->bindtags([$t, grep { $_ ne $t->PathName } $t->bindtags]);

    $t->bind('<Key-slash>',    [$cw, 'Search', 'Next']);
    $t->bind('<Key-question>', [$cw, 'Search', 'Prev']);
    $t->bind('<Key-n>',        [$cw, 'ShowMatch', 'Next']);
    $t->bind('<Key-N>',        [$cw, 'ShowMatch', 'Prev']);

    $t->bind('<Key-g>', $t->bind(ref($t),'<Control-Home>'));
    $t->bind('<Key-G>', $t->bind(ref($t),'<Control-End>'));
    $t->bind('<Home>',  $t->bind('<Key-g>'));
    $t->bind('<End>',   $t->bind('<Key-G>'));

    $t->bind('<Key-j>', [$cw, 'scroll', $t,  1, 'line']);
    $t->bind('<Down>',  [$cw, 'scroll', $t,  1, 'line']);
    $t->bind('<Key-k>', [$cw, 'scroll', $t, -1, 'line']);
    $t->bind('<Up>',    [$cw, 'scroll', $t, -1, 'line']);

    $t->bind('<Key-f>', [$cw, 'scroll', $t,  1, 'page']);
    $t->bind('<Next>',  [$cw, 'scroll', $t,  1, 'page']);
    $t->bind('<Key-b>', [$cw, 'scroll', $t, -1, 'page']);
    $t->bind('<Prior>', [$cw, 'scroll', $t, -1, 'page']);

#    # XXX Not documented (makes sense? --- not yet, but with the std. Text menu)
#    $t->bind('<Key-l>', ['xview', 'scroll',  1, 'units']);
#    $t->bind('<Key-h>', ['xview', 'scroll', -1, 'units']);
    $t->bind('<Return>', ['yview', 'scroll',  1, 'units']);
    $t->bind('<Key-d>',  [$cw, 'scroll', $t,  1, 'halfpage']);
    $t->bind('<Key-u>',  [$cw, 'scroll', $t, -1, 'halfpage']);

    $t->bind('<Key-h>', sub { $cw->Callback(-helpcommand => $t) });

    $e->bind('<Return>',[$cw, 'SearchText']);

    $cw->Delegates('DEFAULT'   => $t,
		   'Search'    => 'SELF',
		   'ShowMatch' => 'SELF',
		  );

    $cw->ConfigSpecs(
		-insertofftime => [$t, qw(insertOffTime OffTime         0)], # no blinking
		-insertwidth   => [$t, qw(insertWidth   InsertWidth     0)], # invisible
		-padx          => [$t, qw(padX          Pad            5p)],
		-pady          => [$t, qw(padY          Pad            5p)],
		-searchcase    => ['PASSIVE', 'searchCase', 'SearchCase', 1],
		-helpcommand   => ['CALLBACK', undef, undef, undef],
		'DEFAULT'      => [$t]
		);

    $cw;
}


sub Search {
    my ($cw, $direction) = @_;
    $cw->{DIRECTION} = $direction;
    my $e = $cw->Subwidget('searchentry');
    $e->configure(-label => 'Search ' . ($direction eq 'Next'?'forward:':'backward:') );
    $e->configure(-relief=>'sunken',-state=>'normal');
    $e->selectionRange(0, "end");
    $e->focus;
}

sub SearchText {
    my ($cw) = @_;
    my($t, $e) = ($cw->Subwidget('text'), $cw->Subwidget('searchentry'));
    $e->historyAdd if ($e->can('historyAdd'));
    unless ($cw->search_text($t, $e->get, 'search') ) {
	$cw->bell;
    }
    $e->configure(-label=>'');
    $t->see('@0,0');
    $cw->ShowMatch($cw->{DIRECTION}, 'firsttime');
    $t->focus;
    $e->configure(-relief=>'flat', -state=>'disabled');
}

sub ShowMatch {
    my ($cw, $method, $firsttime) = @_;

    my $t = $cw->Subwidget('text');
    if ($cw->{DIRECTION} ne 'Next') {
	$method = 'Next' if $method eq 'Prev';
	$method = 'Prev' if $method eq 'Next';
    }
    my $cur = (($method eq 'Prev' && !$firsttime) ||
	       ($method eq 'Next' &&  $firsttime)
	       ? $t->index('@0,0')
	       : $t->index('@0,'.$t->height));
    $method = "tag". $method . "range"; # $method: Next or Prev
    my @ins = $t->$method('search',$cur);
    unless (@ins) {
	$cw->bell;
	return;
    }
    @ins = reverse @ins unless $method eq 'tagNextrange';
    $t->see($ins[0]);
    $ins[0];
}

# Load copied from TextUndo (xxx yy marks changes)
sub Load
{
 my ($text,$file) = @_;
 if (open(FILE,"<$file"))
  {
   $text->MainWindow->Busy;
   $text->SUPER::delete('1.0','end');
   #yy delete $text->{UNDO};
   while (<FILE>)
    {
     $text->SUPER::insert('end',$_);
    }
   close(FILE);
   #yy $text->{FILE} = $file;
   $text->markSet('insert', '@1,0');
   $text->MainWindow->Unbusy;
  }
 else
  {
   $text->messageBox(-message => "Cannot open $file: $!\n");
   die;
  }
}

# search_text copied from demo search.pl (modified)
sub search_text {

    # The utility procedure below searches for all instances of a given
    # string in a text widget and applies a given tag to each instance found.
    # Arguments:
    #
    # w -       The window in which to search.  Must be a text widget.
    # string -  string to search for.  The search is done
    #           using exact matching only;  no special characters.
    # tag -     Tag to apply to each instance of a matching string.

    my($w, $t, $string, $tag) = @_;

    return unless length($string);

    $w->tag('remove',  $tag, qw/0.0 end/);
    my($current, $length, $found) = ('1.0', 0, 0);

    my $insert = $w->index('insert');
    my @search_args = ('-regexp');
    push @search_args, '-nocase' unless ($w->cget('-searchcase'));
    while (1) {
        $current = $w->search(@search_args, -count => \$length, '--', $string, $current, 'end');
        last if not $current;
	$found = 1;
        $w->tag('add', $tag, $current, "$current + $length char");
        $current = $w->index("$current + $length char");
    }
    $w->markSet('insert', $insert);
    $found;
} # end search_text

sub scroll {
    my($w,$t,$no,$unit) = @_;
    if ($unit =~ /^line/) {
	$t->yview('scroll', $no, 'units');
    } else {
	my($y1,$y2) = $t->yview;
	my $amount;
	if ($unit =~ /^halfpage/) {
	    $amount = ($y2-$y1)/2;
	} elsif ($unit =~ /^page/) {
	    $amount = ($y2-$y1);
	} else {
	    die "Unknown unit $unit";
	}
	$y1 += ($no * $amount);
	if ($no > 0) {
	    $y1 = 1.0 if ($y1 > 1.0);
	} else {
	    $y1 = 0.0 if ($y1 < 0.0);
	}
	$t->yviewMoveto($y1);
    }
    Tk->break;
}


#package Tk::More::Status;
#
## Implement status bar
#

1;

__END__

=head1 NAME

Tk::More - a 'more' or 'less' like text widget

=head1 SYNOPSIS

    use Tk::More;

    $more = $parent->More(...text widget options ...);
    $more->Load(FILENAME);

=head1 DESCRIPTION

B<Tk::More> is a readonly text widget with additional key bindings as
found in UNI* command line tools C<more> or C<less>. As in C<more> an
additional status/command line is added at the bottom.

=head1 ADDITIONAL BINDINGS

=over 4

=item Key-g

goto beginning of file

=item Key-G

goto end of file

=item Key-f

forward screen

=item Key-b

backward screen

=item Key-k

up one line

=item Key-j

down one line

=item Key-/

search forward

=item Key-?

search backward

=item Key-n

find next match

=item Key-N

find previous match

=item Key-u

up half screen

=item Key-d

down half screen

=back

=head1 BUGS

Besides that most of more bindings are not implemented. This bugs
me most (high to low priority):

* better status line implementation

* Cursor movement: up/down move displayed area regardless where
  insert cursor is

* add History, Load, Search (also as popup menu)

=head1 SEE ALSO

L<Tk::ROText|Tk::ROText>, more(1), less(1)

=head1 AUTHOR

Achim Bohnet <F<ach@mpe.mpg.de>>

Currently maintained by Slaven Rezic <F<slaven.rezic@berlin.de>>.

Copyright (c) 1997-1998 Achim Bohnet. All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
