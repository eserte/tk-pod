package Tk::More;

use strict;
use vars qw($VERSION @ISA);

$VERSION = substr q$Revision: 1.7 $, 10;

use Tk::Derived;
use Tk::Frame;
@ISA = qw(Tk::Derived Tk::Frame);

Construct Tk::Widget 'More';

#sub ClassInit {
#    my ($class, $mw) = @_;
#
#    $class->SUPER::ClassInit($mw);
#
#    ## xxx: useless 'because it's bound to frame and not rotext :-(
#    $mw->bind($class, '<Key-h>', [qw(xview scroll -1 units)]);
#    $mw->bind($class, '<Key-l>', [qw(xview scroll  1 units)]);
#    $mw->bind($class, '<Key-k>', [qw(yview scroll -1 units)]);
#    $mw->bind($class, '<Key-j>', [qw(yview scroll  1 units)]);
#
#    return $class;
#};

sub Populate {
    my ($cw, $args) = @_;

    require Tk::ROText;
    require Tk::LabEntry;

    $cw->SUPER::Populate($args);

    my $search;
    my $e = $cw->LabEntry(
		-labelPack=>[-side =>'left'],
		-textvariable => \$search,
		-relief => 'flat',
		-state => 'disabled',
		)->pack(-side=>'bottom', -fill => 'x', -expand=>'no');

    my $t = $cw->ROText(-cursor=>undef)->pack(-fill => 'both' , -expand => 'yes');
    $t->tagConfigure('search', -foreground => 'red');

    $t->bind('<Key-slash>',    [$cw, 'Search', $e, 'Next']);
# xxx forw/backw search should be recoded :-(
#    $t->bind('<Key-question>', [$cw, 'Search', $e, 'Prev']);
    $t->bind('<Key-n>',        [$cw, 'ShowMatch', $t, 'Next']);
    $t->bind('<Key-N>',        [$cw, 'ShowMatch', $t, 'Prev']);

    $t->bind('<Key-G>', $t->bind(ref($t),'<Control-End>'));
    $t->bind('<Key-j>', ['yview', 'scroll',  1, 'units']);
    $t->bind('<Key-k>', ['yview', 'scroll', -1, 'units']);
    $t->bind('<Key-f>', $t->bind(ref($t),'<Next>'));
    $t->bind('<Key-b>', $t->bind(ref($t),'<Prior>'));

    # Not documented (makes sense?)
    $t->bind('<Key-l>', ['xview', 'scroll',  1, 'units']);
    $t->bind('<Key-h>', ['xview', 'scroll', -1, 'units']);
#    $t->bind('<Key-h>', $t->bind(ref($t),'<Left>'));
#    $t->bind('<Key-l>', $t->bind(ref($t),'<Right>'));
    $t->bind('<Return>', $t->bind(ref($t),'<Down>'));
    $t->bind('<space>', $t->bind(ref($t),'<Next>'));
    $t->bind('<Key-d>', $t->bind(ref($t),'<Next>'));  # xxx should be 1/2 screen
    $t->bind('<Key-u>', $t->bind(ref($t),'<Prior>')); # xxx should be 1/2 screen

    $e->bind('<Return>',[$cw, 'SearchText', $t, $e]);

    $cw->Delegates('DEFAULT' => $t);

    $cw->ConfigSpecs(
		-insertofftime => [$t, qw(insertOffTime OffTime         0)], # no blinking
		-insertwidth   => [$t, qw(insertWidth   InsertWidth     0)], # invisible
		-padx          => [$t, qw(padX          Pad            5p)],
		-pady          => [$t, qw(padY          Pad            5p)],
		'DEFAULT'      => [$t]
		);

    $cw;
}

sub Search {
    my ($cw, $e, $direction) = @_;
    $cw->{DIRECTION} = $direction;
    $e->configure(-label => 'Search ' . ($direction eq 'Next'?'forward:':'backward:') );
    $e->configure(-relief=>'sunken',-state=>'normal');
    $e->focus;
}

sub SearchText {
    my ($cw, $t, $e) = @_;
    unless ($cw->search_text($t, $e->get, 'search') ) {
	$cw->bell;
    }
    $e->configure(-label=>'');
    $t->see( '@1,0' );
    # xxx better start at current pos as in more ???
    $t->markSet('insert' ,'@1,0');
    $cw->ShowMatch($t,$cw->{DIRECTION});
    $t->focus;
    $e->configure(-relief=>'flat', -state=>'disabled');
}

# xxx when search changes from forward to backward (or vice versa)
#     'insert' jumps from end to start of match (start to end)
#     instead of the next (prev) match
sub ShowMatch {
    my ($cw, $t, $method) = @_;
    if ($cw->{DIRECTION} ne 'Next') {
	$method = 'Next' if $method eq 'Prev';	
	$method = 'Prev' if $method eq 'Next';	
    }
    my $cur = $t->index('insert');
    $method = "tag". $method . "range"; # $method: Next or Prev
    my @ins = $t->$method('search',$cur);
    unless (@ins) {
	$cw->bell;
	return;
    }
    @ins = reverse @ins unless $method eq 'tagNextrange';
    $t->markSet('insert' ,$ins[1]);
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
   $text->MainWindow->Unbusy;
  }
 else
  {
   $text->BackTrace("Cannot open $file:$!");
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
    while (1) {
        $current = $w->search(-regexp, -count => \$length, '--', $string, $current, 'end');
        last if not $current;
	$found = 1;
        $w->tag('add', $tag, $current, "$current + $length char");
        $current = $w->index("$current + $length char");
    }
    $w->markSet('insert', $insert);
    $found;
} # end search_text



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
found in UNI* command line tool C<more>.  As in C<more> an additional
status/command line is added at the bottom.

=head1 ADDITIONAL BINDINGS

=over 4

=item Key-G

goto end of file

=item Key-f

like next key

=item Key-b

like prior key

=item Key-k

like up key

=item Key-j

like down key

=item Key-/

search forward

=item Key-n

find next match

=item Key-N

find previous match

=back

=head1 BUGS

Besides that most of more bindings are not implemented. This bugs
me most (high to low priority):

* Reverse search missing

* better status line implementation

* Cursor movement: up/down move displayed area regardless where
  insert cursor is

* add History, Load, Search (also as popup menu)

* Key-u and Key-d should move 1/2 screen and not 90% of a screen

* bad history impl.

=head1 SEE ALSO

L<Tk::ROText|Tk::ROText>
more(1)

=head1 AUTHOR

Achim Bohnet <F<ach@mpe.mpg.de>>

Copyright (c) 1997-1998 Achim Bohnet. All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
