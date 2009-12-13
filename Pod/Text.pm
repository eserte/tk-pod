package Tk::Pod::Text;

use strict;
use Carp;
use Config;
use Tk::Frame;
use Tk::Pod;
use Tk::Parse;

use vars qw($VERSION @ISA @POD $IDX);
$VERSION = substr(q$Revision: 1.20 $, 10) + 1 . "";
@ISA = qw(Tk::Frame);

Construct Tk::Widget 'PodText';

BEGIN { @POD = (@INC, grep(-d, split($Config{path_sep}, 
				     $ENV{'PATH'}))); $IDX = undef; };

sub Dir
{
 my $class = shift;
 unshift(@POD,@_);
}

sub Find
{
 my ($file) = @_;
 my $dir;
 foreach $dir ("",@POD)
  {
   my $prefix;
   foreach $prefix ("","pod/")
    {
     my $suffix;
     foreach $suffix ("",".pod",".pm")
      {
       my $path = "$dir/" . $prefix . $file . $suffix;
       return $path if (-r $path && -T $path);
       $path =~ s,::,/,g;
       return $path if (-r $path && -T $path);
      }
    }
  }
  return undef;
}

sub findpod {
    my ($w,$name) = @_;
    $w->BackTrace("Invalid path/file/module name: '$name'") if $name !~ /^[-_+:.\/A-Za-z0-9]+$/;
    Find($name) or $w->BackTrace("Can't find POD Invalid file/module name: '$name'");
}

sub file {
  my $w = shift;
  if (@_)
    {
      #print "loading $_[0] ...\n";
      my $file = shift;
      $w->{'File'} = $file;
      my $path = $w->findpod($file);
      my $last = $w->cget('-path');
      $w->history_add($last) if $last;
      $w->configure('-path' => $path);
      $w->delete('1.0' => 'end');
      #use Benchmark;
      # my $t = new Benchmark;
      $w->process($path);
      # print &timediff(new Benchmark, $t)->timestr,"\n";
    }
  else
    {
      return $w->{'File'};
    }
}

sub reload
{
 my ($w) = @_;
 # remember old y position
 my ($currpos) = $w->yview;
 $w->delete('0.0','end');
 $w->process($w->cget('-path'));
 # restore old y position
 $w->yview(moveto => $currpos);
 # set (invisible) insertion cursor into the visible text area
 $w->markSet(insert => '@0,0');
}

sub edit
{
 my ($w) = @_;
 my $path = $w->cget('-path');
 my $edit = $ENV{XEDITOR} || $ENV{VISUAL} || $ENV{'EDITOR'} || 'vi';
 if (defined $edit)
  {
   if (fork)
    {
     wait; # parent
    }
   else
    {
     #child
     if (fork)
      {
       # still child
       exec("true");
      }
     else
      {
       # grandchild 
       exec("$edit $path");
      }
    }
  }
}

sub Populate
{
 my ($w,$args) = @_;

    require Tk::More;

    $w->SUPER::Populate($args);

    $w->privateData()->{history} = [];
     
    my $p = $w->Scrolled('More', -scrollbars => 'w');
    $w->Advertise('more' => $p->Subwidget('more'));
    $p->pack(-expand => 1, -fill => 'both');
    # XXX Subwidget stuff needed because Scrolled does not
    #     delegate bind, bindtag to the scrolled widget. Tk402.* (and before?)
    #	  (patch posted and included in Tk402.004)
    $p->Subwidget('scrolled')->bind('<Double-1>',      [$w, 'DoubleClick']);
    $p->Subwidget('scrolled')->bind('<Shift-Double-1>',[$w, 'ShiftDoubleClick']);


 $p->configure(-font => $w->Font(family => 'courier'));
 $p->tag('configure','text', -font => $w->Font(family => 'times'));
 $p->tag('configure','C',-font => $w->Font(family=>'courier',   weight=>'medium'              ));
 $p->tag('configure','S',-font => $w->Font(family=>'courier',   weight=>'bold',   slant => 'o'));
 $p->tag('configure','B',-font => $w->Font(family=>'times',     weight=>'bold',               ));
 $p->tag('configure','I',-font => $w->Font(family=>'times',     weight=>'medium', slant => 'i'));
 $p->tag('configure','S',-font => $w->Font(family=>'times',     weight=>'medium', slant => 'i'));
 $p->tag('configure','F',-font => $w->Font(family=>'helvetica', weight=>'bold',               ));
 $p->insert('0.0',"\n");

 $w->{List}   = []; # stack of =over
 $w->{Item}   = undef;
 $w->{'indent'} = 0;
 $w->{Length}  = 64;
 $w->{Indent}  = {}; # tags for various indents

    my $m = $p->Menu(-tearoff => 0);
    $p->Subwidget('scrolled')->bind('<Button-3>', sub {
		$m->Popup(-popover => 'cursor', -popanchor => 'nw')});
    $m->command(-label => 'Back', -command =>
		sub {
		    $w->configure('-file' => $w->history_back)
			 if $w->history_size;
		    $w->history_back; # XXX arrgh, logic!. Todo: Forward (cmp Tk/Web.pm)
		} );
    $m->command(-label => 'Reload', -command => sub{$w->reload} );
    $m->command(-label => 'Edit',   -command => sub{$w->edit} );
    $m->command(-label => 'Search...', -command => ['SearchFullText', $w]);
    $w->Delegates(DEFAULT => $p,
		  'SearchFullText' => 'SELF',
		 );

    $w->ConfigSpecs(
            '-file'       => ['METHOD'  ],
            '-path'       => ['PASSIVE' ],
            '-poddone'    => ['CALLBACK'],

            '-wrap'       => [ $p, qw(wrap       Wrap       word) ],
	    # -font ignored because it does not change the other fonts
	    #'-font'	  => [ 'PASSIVE', undef, undef, undef],
            '-scrollbars' => [ $p, qw(scrollbars Scrollbars w   ) ],

            'DEFAULT'     => [ $p ],
            );

    $args->{-width} = $w->{Length};
}

my %tag = qw(C 1 B 1 I 1 L 1 F 1 S 1 Z 1);

sub Font
{
 my ($w,%args)    = @_;
 $args{'family'}  = 'times'  unless (exists $args{'family'});
 $args{'weight'}  = 'medium' unless (exists $args{'weight'});
 $args{'slant'}   = 'r'      unless (exists $args{'slant'});
 $args{'size'}    = 140      unless (exists $args{'size'});
 $args{'spacing'} = '*'     unless (exists $args{'spacing'});
 $args{'slant'}   = substr($args{'slant'},0,1);
 my $name = "-*-$args{'family'}-$args{'weight'}-$args{'slant'}-*-*-*-$args{'size'}-*-*-$args{'spacing'}-*-iso8859-1";
 return $name;
}

sub ShiftDoubleClick
{
 my ($w) = @_;
 my $sel = $w->SelectionGet;
 if (defined $sel)
  {
   my $file;
   if ($file = $w->findpod($sel)) {
       $w->MainWindow->Pod('-file' => $sel);
   } else {
       $w->BackTrace("No POD documentation found for '$sel'");
   }
  }
}

sub DoubleClick
{
 my ($w) = @_;
 my $sel = $w->SelectionGet;
 if (defined $sel)
  {
   my $file;
   if ($file = $w->findpod($sel)) {
       $w->configure('-file'=>$file);
   } else {
       $w->BackTrace("No POD documentation found for '$sel'");
   }
  }
}

sub Link
{
 my ($w,$how,$index,$link) = @_;

 #print STDERR "how=$how|index=$index|link=$link|\n";
 # FIX another ugly hack, breaks with $how
 $link =~ s|^/||;
 my (@range) = $w->tag('nextrange',$link, '1.0');
 @range = $w->tag('nextrange',"\"$link\"",'1.0') unless @range == 2;
 # XXX wrong if mode is 'new'  
 if (@range == 2)
  {
   #print "range $range[0], $range[1], |", $w->get(@range), "|\n";
   $w->yview("$range[0] linestart");
  }
 else
  {
   my $man = $link;
   #   $man =~ s/^"/\/"/;  # L<"sec"> ==> L</"sec">
   my $sec;
   ($man,$sec) = split(m#/#,$link) if ($link =~ m#/#);
   $man =~ s/::/\//g;
   if ($how eq 'reuse')
    {
     my $file = $w->cget('-file');
     #print "man=($man) file=(",$file,")\n";
     $w->configure('-file' => $man)
	unless ( defined $file and ($file =~ /$man\.\w+$/ or $file eq $man) );
    }
   else
    {
     #print "after  man=($man)\n";
     $man = $w->cget('-file') if ($man eq "");
     #print "before man=($man)\n";
     $w = $w->MainWindow->Pod('-file' => $man);
    }
   # XXX big docs like Tk::Text take too long until
   #     they return
   if (defined $sec)
     {   
        #print "end  man=($sec)\n";
        # handle sections: head1, head2 and items
        my $start = ($w->tag('nextrange',$sec, '1.0'))[0];
        $w->BackTrace("Section '$sec' not found\n") unless (defined $start);
        $w->yview("$start linestart");
     }
  }
}

sub SearchFullText {
    my $w = shift;
    unless (defined $IDX && $IDX->IsWidget) {
	require Tk::Pod::Search; #
	$IDX = $w->Toplevel(-title=>'Perl Library Full Text Search');
	$IDX->PodSearch(
			-command =>
			sub{
			    $w->configure('-file' => shift);
			    $w->focus;
			}
		       )->pack(-fill=>'both',-expand=>'both');
    }
    $IDX->deiconify;
    $IDX->raise;
    (($IDX->children)[0])->focus;
} 

my %translate =
(
 'lt'    => '<',
 'gt'    => '>',
 'amp'   => '&',
 'auml'  => '�',
 'Auml'  => '�',
 'ouml'  => '�',
 'Ouml'  => '�',
 'uuml'  => '�',
 'Uuml'  => '�',
 'space' => ' ',
 'szlig' => '�',
 'tab'   => "\t",
 );

# '<' and '>' have been replaced with \x7f because E<..> have been
# turned into real characters.
sub _expand
{
 my ($w,$line) = @_;

 if ($line =~ /^(.*?)\b([A-Z])\x7f(.*?)\x7f(.*)$/)
  {
   my ($pre,$tag,$what,$post) = ($1,$2,$3,$4);
   $w->insert('end -1c',$pre);
    {
     my $start = $w->index('end -1c');
     $what = $w->_expand($what);         
     if ($tag eq 'L')
      {
       if ($what =~ s/^([^|\x7f]+)\|//) # L<showthis|man/sec>
         {
            my $show = $1;
            # print "man/sec=($what) show=($show)\n";
            $w->delete("$start +".length($show)."c", "end -1c");	
         }
       $tag = '!'.$what;
       # XXX: ButtonRelease is same as Button due to tag('nextrange'...)
       # so leaving link area with pressed button nevertheless selects
       # a link when button is released
       $w->tag('bind',$tag, '<ButtonRelease-1>',
		[$w,'Link', 'reuse',Tk::Ev('@%x,%y'),$what]);
       $w->tag('bind',$tag, '<Shift-ButtonRelease-1>',
		[$w,'Link', 'new',  Tk::Ev('@%x,%y'),$what]);
       $w->tag('bind',$tag, '<ButtonRelease-2>',
		[$w,'Link', 'new',  Tk::Ev('@%x,%y'),$what]);
       $w->tag('configure',$tag,
		-underline  => 1,
		-foreground => 'blue',
		);
      }
     $w->tag('add',$tag,$start,'end -1c');
    }
   $post = $w->_expand($post);
   return $pre . $what . $post;
  }
 else
  {
   $w->insert('end -1c',$line);
   return $line;
  }
}

sub expand
{
 my ($w,$line) = @_;

 $line =~ s/[<>]/\x7f/g;

 $line =~ s/E\x7f([A-Za-z]*)\x7f/$translate{$1}/g;
 return (_expand ($w, $line));
}

sub append
{
 my $w = shift;
 my $line;
 foreach $line (@_)
  {
   $w->expand($line);
  }
}

sub text
{
 my ($w,$body) = @_;
 $body = join(' ',split(/\s*\n/,$body));
 my $start = $w->index('end -1c');
 $w->append($body,"\n\n");
 $w->tag('add','text',$start,'end -1c');
}

sub verbatim
{
 my ($w,$body) = @_;
 my $line;
 foreach $line (split(/\n/,$body))
  {
   # Really need to have length after tabs expanded.
   my $l = length($line)+$w->{indent};
   if ($l > $w->{Length})
    {
     $w->{Length} = $l;
     $w->configure(-width => $l) if ($w->viewable);
    }
  }
 $w->insert('end -1c',$body . "\n\n",['verbatim']);
}

my $num;

sub head1
{
 my ($w,$title) = @_;
 my $start = $w->index('end -1c');
# my $tag = "\"$title\"";  # XXX needed?
 my $tag = "title";
 $w->append($title);
 $num = 2 unless (defined $num);
 $w->tag('add',$tag,$start,'end -1c');
 $w->tag('configure',$tag,-font => $w->Font(family => 'times', 
         weight => 'bold',size => 180));
 $w->tag('raise',$tag,'text');
 $w->append("\n\n");
}

sub head2
{
 my ($w,$title) = @_;
 my $tag ="\"$title\""; 
 my $start = $w->index('end -1c');
 $w->append($title);
 $w->tag('add',$tag,$start,'end -1c');
 $w->tag('configure',$tag,
         -font => $w->Font(family => 'times', weight => 'bold'));
 $w->tag('raise',$tag,'text');
 $w->append("\n\n");
}

*head3 = \&head2;

sub IndentTag
{
 my ($w,$indent) = @_;
 my $tag = "Indent" . ($indent+0);
 unless (exists $w->{Indent}{$tag})
  {
   $w->{Indent}{$tag} = $indent;
   $indent *= 8;
   $w->tag('configure',$tag,
           -lmargin2 => $indent . 'p', 
           -rmargin  => $indent . 'p', 
           -lmargin1 => $indent . 'p'
          );
  }
 return $tag;
}

sub enditem
{
 my ($w) = @_;
 my $item = delete $w->{Item};
 if (defined $item)
  {
   my ($start,$indent) = @$item;
   $w->tag('add',$w->IndentTag($indent),$start,'end -1c');
  }
}

sub item
{
 my ($w,$title) = @_;
 $w->enditem;
 my $type = $w->{listtype};
 my $indent = $w->{indent};
 #print STDERR "item(",join(',',@_,$type,$indent),")\n" unless ($type == 1 || $type == 3);
 my $start = $w->index('end -1c');
 $title =~ s/\n/ /;
 $w->append($title);
 $w->tag('add',$title,$start,'end -1c');
 $w->tag('configure',$title,-font => $w->Font(weight => 'bold'));
 $w->tag('raise',$title,'text');
 $w->append("\n") if ($type == 3);
 $w->append(" ")  if ($type != 3);
 $w->{Item} = [ $w->index('end -1c'), $w->{indent} ];
}

sub setindent 
{ 
 my ($w,$arg) = @_; 
 $w->{'indent'} = $arg 
}

sub listbegin 
{ 
 my ($w) = @_;
 my $item = delete $w->{Item};
 push(@{$w->{List}},$item);
}

sub listend
{
 my ($w) = @_;
 $w->enditem;
 $w->{Item} = pop(@{$w->{List}});
}

sub over { } 

sub back { } 

# XXX PodText.pm should not manipulate Toplevel
sub filename
{
 my ($w,$title) = @_;
 $w->toplevel->title($title);
}

sub setline   {}
sub setloc    {}
sub endfile   {}
sub listtype  { my ($w,$arg) = @_; $w->{listtype} = $arg }
sub cut       {} 

sub process
{
 my ($w,$file) = @_;
 my @save = @ARGV;
 @ARGV = $file;
 $w->toplevel->Busy;
# print STDERR "Parsing $file\n";
 my (@pod) = Simplify(Parse());
 my ($cmd,$arg);
# print STDERR "Render $file\n";
 my $update = 2;
 undef @{$w->{'sections'}};
 while ($cmd = shift(@pod))
  {
   my $arg = shift(@pod);
   if ($cmd =~ /^head(\d+)/) {
       my $head = $1;
       my $arg = $arg;
       $arg =~ s/E<([^>]+)>/$Tk::Parse::Escapes{$1}/g;
       push @{$w->{'sections'}}, [$head, $arg, $w->index('end')];
   }
   $w->$cmd($arg);
   unless ($update--) {
     $w->update;
     $update = 2;
   }
  }
 $w->parent->add_section_menu if $w->parent->can('add_section_menu');
 $w->Callback('-poddone', $file);
 # set (invisible) insertion cursor to top of file
 $w->markSet(insert => '@0,0');
 $w->toplevel->Unbusy;
 @ARGV = @save;
}

sub history_add {
    my ($w,$file) = @_;
    #print STDERR "History add  = '$file'\n";
    $w->BackTrace("Not a text file '$file'. Can't add to history\n")
	    unless -f $file;
    my $hist = $w->privateData()->{history};
    push @$hist, $file;
    undef;
}

sub history_back {
    my ($w) = @_;
    my $hist = $w->privateData()->{history};
    if (@$hist) {
        #print STDERR "History last = ", $w->privateData()->{history}->[-1], "\n";
    	return pop(@$hist)
    } else {
        $w->BackTrace("History is empty");
    }
}

sub history_size {
    my ($w) = @_;
    #print STDERR "History size = ", scalar(@{ $w->privateData()->{history} }), "\n";
    scalar @{ $w->privateData()->{history} };
}

1;

__END__

=head1 NAME

Tk::Pod::Text - POD browser widget


=head1 SYNOPSIS

    use Tk::Pod::Text;

    $pod = $parent->PodText(
		-file		=> ?
		-scrollbars	=> ?
		);

    $file = $pod->cget('-path');   # ?? the name path is confusing :-(

=cut

# also works with L<show|man/sec>. Therefore it stays undocumented :-)
 
#    $pod->Link(manual/section)	# as L<manual/section> see perlpod 


=head1 DESCRIPTION

B<Tk::Pod::Text> is a readonly text widget that can display POD
documentation.


=head1 SEE ALSO

L<Tk::More|Tk::More>
L<Tk::Pod|Tk::Pod>
L<perlpod|perlpod>
L<tkpod|tkpod>
L<perlindex|perlindex>


=head1 KNOWN BUGS

See TODO files of Tk-Pod distribution



=head1 POD TO VERIFY B<PodText> WIDGET

For B<PodText> see L<Tk::Pod::Text>.

A C<fixed width> font.

Text in I<slant italics>.

A <=for> paragraph is hidden between here

=for refcard  this should not be visisble.

and there.

A file: F</usr/local/bin/perl>.  A variable $a without markup.

S<boofar> is in SE<lt>E<gt>.

German Umlaute:

=over 4

=item auml: E<auml>,

=item Auml: E<Auml>,

=item ouml: E<ouml>,

=item Ouml: E<Ouml>,

=item Uuml: E<uuml>,

=item Uuml: E<Uuml>,

=item sz: E<szlig>.

=back

Pod with Umlaut: L<ExtUtils::MakeMaker> and ExtUtils::MakeMaker.

Details:  L<perlpod> or perl, perlfunc.

Here some code in a as is paragraph

    use Tk;
    my $mw = MainWindow->new;
    ...
    MainLoop
    __END__


Fonts: S<sanserif>, C<fixed>, B<bold>, I<italics>, normal, or file
F</path/to/a/file>

Mixed Fonts: B<S<bold-sanserif>>, B<C<bold-fixed>>, B<I<bold-italics>>

Other POD docu: Tk::Font, Tk::BrowseEntry

=head1 AUTHOR

Nick Ing-Simmons <F<nick@ni-s.u-net.com>>

Code currently maintained by Achim Bohnet <F<ach@mpe.mpg.de>>.
Please send bug reports to <F<ptk@lists.stanford.edu>>.

Copyright (c) 1998 Nick Ing-Simmons.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

