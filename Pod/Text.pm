
require 5;
package Tk::Pod::Text;

use strict;

BEGIN {  # Make a DEBUG constant very first thing...
  if(defined &DEBUG) {
  } elsif(($ENV{'TKPODDEBUG'} || '') =~ m/^(\d+)/) { # untaint
    eval("sub DEBUG () {$1}");
    die "WHAT? Couldn't eval-up a DEBUG constant!? $@" if $@;
  } else {
    *DEBUG = sub () {0};
  }
}

use Carp;
use Config;
use Tk::Frame;
use Tk::Pod;
#XXX del: use Tk::Parse;
use Tk::Pod::SimpleBridge;

use vars qw($VERSION @ISA @POD $IDX);
$VERSION = substr(q$Revision: 3.17 $, 10) + 1 . "";
@ISA = qw(Tk::Frame Tk::Pod::SimpleBridge);

BEGIN { DEBUG and print "Running ", __PACKAGE__, "\n" }

Construct Tk::Widget 'PodText';

BEGIN {
  @POD = (
   @INC,
   $ENV{'PATH'} ?
     grep(-d, split($Config{path_sep}, $ENV{'PATH'}))
    : ()
  );
  $IDX = undef;
  DEBUG and print "POD: @POD\n";
};

use Class::Struct;
struct '_HistoryEntry' => [
    'file'  => '$',
    'index' => '$',
];
sub _HistoryEntry::create {
    my $o = shift->new;
    $o->file(shift);
    $o->index(shift);
    $o;
}

use constant HISTORY_DIALOG_ARGS => [-icon => 'info',
				     -title => 'History Error',
				     -type => 'OK'];
sub Dir
{
 my $class = shift;
 unshift(@POD,@_);
}

sub Find
{
 my ($file) = @_;
 return $file if (-f $file);
 my $dir;
 foreach $dir ("",@POD)
  {
   my $prefix;
   foreach $prefix ("","pod/","pods/")
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
    unless (defined $name and length $name) {
	$w->messageBox(
	  -title => "Tk::Pod Error",
          -message => "Empty POD file/name",
	);
	die;
    }

    my $absname;
    if (-f $name) {
	$absname = $name;
    } else {
	if ($name !~ /^[-_+:.\/A-Za-z0-9]+$/) {
	    $w->messageBox(
	      -title => "Tk::Pod Error",
	      -message => "Invalid path/file/module name: '$name'\n");
	    die;
	}
	$absname = Find($name);
    }
    if (!defined $absname) {
	$w->messageBox(
	  -title => "Tk::Pod Error",
	  -message => "Can't find POD. Invalid file/module name: '$name'\n"
	);
	die;
    }
    if (eval { require File::Spec; File::Spec->can("rel2abs") }) {
	DEBUG and print "Turn $absname into an absolute file name";
	$absname = File::Spec->rel2abs($absname);
    }
    $absname;
}

sub file {   # main entry point
  my $w = shift;
  if (@_)
    {
      #print "loading $_[0] ...\n";
      my $file = shift;
      $w->{'File'} = $file;
      my $path = $w->findpod($file);
      if (!$w->privateData()->{'from_history'}) {
	  $w->history_modify_entry;
	  $w->history_add($path, "1.0");
      }
      $w->configure('-path' => $path);
      $w->delete('1.0' => 'end');
      my $tree_sw = $w->parent->Subwidget("tree");
      if ($tree_sw) {
	  $tree_sw->SeePath("file:$path");
      }
      #use Benchmark;
      # my $t = new Benchmark;
      $w->process($path);
      # print &timediff(new Benchmark, $t)->timestr,"\n";
      $w->focus;
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
 my ($w,$edit) = @_;
 my $path = $w->cget('-path');
 if ($^O eq 'MSWin32') # XXX what is right?
  {
   system("ptked $path");
  }
 else
  {
   if (!defined $edit)
    {
     # VISUAL and EDITOR are supposed to have a terminal, but tkpod can
     # be started without a terminal.
     my $isatty = is_interactive();
     $edit = $ENV{XEDITOR};
     if (!$isatty && !defined $edit)
      {
       $w->messageBox(
	 -title => "Tk::Pod Error",
         -message => "No terminal, fallback to ptked"
       );
       $edit = 'ptked';
      }
     else
      {
       $edit = $ENV{VISUAL} || $ENV{'EDITOR'} || '/usr/bin/vi';
      }
    }

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
}

sub Populate
{
    my ($w,$args) = @_;

    require Tk::More;

    $w->SUPER::Populate($args);

    $w->privateData()->{history} = [];
    $w->privateData()->{history_index} = -1;

    my $p = $w->Scrolled('More',
			 -helpcommand => sub {
			     $w->parent->help if $w->parent->can('help');
			 },
			 -scrollbars => $Tk::platform eq 'MSWin32' ? 'e' : 'w');
    my $p_scr = $p->Subwidget('more');
    $w->Advertise('more' => $p_scr);
    $p->pack(-expand => 1, -fill => 'both');

    # XXX Subwidget stuff needed because Scrolled does not
    #     delegate bind, bindtag to the scrolled widget. Tk402.* (and before?)
    #	  (patch posted and included in Tk402.004)
    $p_scr->bindtags([$p_scr, $p_scr->bindtags]);
    $p_scr->bind('<Double-1>',       sub  { $w->DoubleClick($_[0]) });#[$w, 'DoubleClick']);
    $p_scr->bind('<Shift-Double-1>', sub  { $w->ShiftDoubleClick($_[0]) });#[$w, 'ShiftDoubleClick', $_[0]]);

    $p->configure(-font => $w->Font(family => 'courier'));

#XXX del:
    #$p->tag('configure','verbatim', -wrap => 'none');
    $p->tag('configure','text', -font => $w->Font(family => 'times'));
    #$p->tag('configure','C',-font => $w->Font(family=>'courier',   weight=>'medium'              ));
    #$p->tag('configure','B',-font => $w->Font(                     weight=>'bold',               ));
    ##$p->tag('configure','S',-font => $w->Font(                                                   ));
    #$p->tag('configure','I',-font => $w->Font(                                       slant => 'i'));
    #$p->tag('configure','F',-font => $w->Font(                                       slant => 'i'));

    $p->insert('0.0',"\n");

    $w->{List}   = []; # stack of =over
    $w->{Item}   = undef;
    $w->{'indent'} = 0;
    $w->{Length}  = 64;
    $w->{Indent}  = {}; # tags for various indents

    # Seems like a perl bug: ->can() does not work before actually calling
    # the subroutines (perl5.6.0 isa bug?)
    eval {
	$p->EditMenuItems;
	$p->SearchMenuItems;
	$p->ViewMenuItems;
    };

    my $m = $p->Menu
	(-tearoff => $Tk::platform ne 'MSWin32',
	 -menuitems =>
	 [
	  [Button => 'Back',     -command => [$w, 'history_move', -1]],
	  [Button => 'Forward',  -command => [$w, 'history_move', +1]],
	  [Button => 'Reload',   -command => sub{$w->reload} ],
	  [Button => 'Edit POD',       -command => sub{$w->edit} ],
	  [Button => 'Search fulltext',-command => ['SearchFullText', $w]],
	  [Separator => ""],
	  [Cascade => 'Edit',
	   ($Tk::VERSION > 800.015 && $p->can('EditMenuItems') ? (-menuitems => $p->EditMenuItems) : ()),
	  ],
	  [Cascade => 'Search',
	   ($Tk::VERSION > 800.015 && $p->can('SearchMenuItems') ? (-menuitems => $p->SearchMenuItems) : ()),
	  ],
	  [Cascade => 'View',
	   ($Tk::VERSION > 800.015 && $p->can('ViewMenuItems') ? (-menuitems => $p->ViewMenuItems) : ()),
	  ]
	 ]);
    eval { $p->menu($m) }; warn $@ if $@;

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
            '-scrollbars' => [ $p, qw(scrollbars Scrollbars), $Tk::platform eq 'MSWin32' ? 'e' : 'w' ],

            'DEFAULT'     => [ $p ],
            );

    $args->{-width} = $w->{Length};
}

#my %tag = qw(C 1 B 1 I 1 L 1 F 1 S 1 Z 1); # un-used XXX

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

sub ShiftDoubleClick {
    shift->DoubleClick(shift, 'new');
}

sub DoubleClick
{
 my ($w,$ww,$how) = @_;
 my $Ev = $ww->XEvent;
 $w->SelectToModule($Ev->xy);
 my $sel = $w->SelectionGet;
 if (defined $sel)
  {
   my $file;
   if ($file = $w->findpod($sel)) {
       if (defined $how && $how eq 'new')
	{
         $w->MainWindow->Pod('-file' => $sel);
	}
       else
	{
         $w->configure('-file'=>$file);
        }
   } else {
       $w->messageBox(
         -title => "Tk::Pod Error",
         -message => "No Pod documentation found for '$sel'\n"
       );
       die;
   }
  }
 Tk->break;
}

sub Link
{
 my ($w,$how,$index,$man,$sec) = @_;

 # If clicking on a Link, the <Leave> binding is never called, so it
 # have to be done here:
 $w->LeaveLink;

 $man = '' unless defined $man;
 $sec = '' unless defined $sec;

 if ($how eq 'reuse' && $man ne '')
  {
   my $file = $w->cget('-file');
   $w->configure('-file' => $man)
    unless ( defined $file and ($file =~ /$man\.\w+$/ or $file eq $man) );
  }

 if ($how eq 'new')
  {
   $man = $w->cget('-file') if ($man eq "");
   my $tree = eval { $w->parent->cget(-tree) };
   $w = $w->MainWindow->Pod('-tree' => $tree);
   $w->configure('-file' => $man); # see tkpod for the same problem
  }
  # XXX big docs like Tk::Text take too long until they return

 if ($sec ne '' && $man eq '') # XXX reuse vs. new`
  {
   $w->history_modify_entry;
  }

 if ($sec ne '')
  {
   # XXX the $start-setting logic doesn't seem to work right

   DEBUG and print "Looking for section \"$sec\"...\n";
   DEBUG and print "Trying a search across Sections entries...\n";

   my $start;

   foreach my $s ( @{$w->{'sections'} || []} ) {
     if($s->[1] eq $sec) {
       DEBUG and print " $sec is $$s[1] (at $$s[2])\n";
       $start = $s->[2];

       my($line) = split(/\./, $start);
       $w->tag('remove', '_section_mark', qw/0.0 end/);
       $w->tag('add', '_section_mark',
		  $line-1 . ".0",
		  $line-1 . ".0 lineend");
       $w->yview("_section_mark.first");
       $w->after(500, [$w, qw/tag remove _section_mark 0.0 end/]);
       return;
     } else {
       DEBUG > 2 and print " Nope, it's not $$s[1] (at $$s[2])\n";
     }
   }


   if( defined $start ) {
     DEBUG and print " Found at $start\n";
   } else {
     $start = ($w->tag('nextrange',$sec, '1.0'))[0];
   }

   my $link = ($man || '') . $sec;

   if( defined $start ) {
     DEBUG and print " Found at $start\n";
   } else {
     DEBUG and print " Not found so far.  Using a quoted nextrange search...\n";
     $start = ($w->tag('nextrange',"\"$link\"",'1.0'))[0];
   }

   if( defined $start ) {
     DEBUG and print " Found at $start\n";
   } else {
     $start = $w->search(qw/-exact -nocase --/, $sec, '1.0');
   }


   unless (defined $start)
    {
     DEBUG and print " Not found! (\"sec\")\n";

     $w->messageBox(
       -title   => "Tk::Pod Error",
       -message => "Section '$sec' not found\n"
     );
     die;
    }
   DEBUG and print "link-zapping to $start linestart\n";
   $w->yview("$start linestart");
  }

 if ($sec ne '' && $man eq '') # XXX reuse vs. new`
  {
   $w->history_add($w->cget(-path), $w->index('@0,0'));
  }

}

sub EnterLink {
    my $w = shift;
    $w->configure(-cursor=>'hand2');
}

sub LeaveLink {
    my $w = shift;
    $w->configure(-cursor=>undef);
}

sub SearchFullText {
    my $w = shift;
    unless (defined $IDX && $IDX->IsWidget) {
	require Tk::Pod::Search; #
	$IDX = $w->Toplevel(-title=>'Perl Library Full Text Search');
	$IDX->PodSearch(
			-command =>
			sub {
			    my($pod, %args) = @_;
			    $w->configure('-file' => $pod);
			    $w->focus;
			    my $more = $w->Subwidget('more');
			    $more->SearchText
				(-direction => 'Next',
				 -quiet => 1,
				 -searchterm => $args{-searchterm},
				 -onlymatch => 1,
				);
			}
		       )->pack(-fill=>'both',-expand=>'both');
    }
    $IDX->deiconify;
    $IDX->raise;
    $IDX->bind('<Escape>' => [$IDX, 'destroy']);
    (($IDX->children)[0])->focus;
}

sub Print {
    my $w = shift;
    my $path = $w->cget(-path);
    if (!-r $path) {
	$w->messageBox(
          -title   => "Tk::Pod Error",
	  -message => "Cannot find file `$path`"
	);
	die;
    }

    if ($ENV{'TKPODPRINT'}) {
	my @cmd;
	if ($ENV{'TKPODPRINT'} =~ /%s/) {
	    ($cmd[0] = $ENV{'TKPODPRINT'}) =~ s/%s/$path/g;
	} else {
	    @cmd = ($ENV{'TKPODPRINT'}, $path);
	}
	DEBUG and print "Running @cmd\n";
	system @cmd;
	return;
    } elsif ($^O =~ m/Win32/) {
	return $w->Print_MSWin($path);
    }
    # otherwise fall thru...

    if (!eval { require POSIX; 1 }) {
	$w->messageBox(
          -title   => "Tk::Pod Error",
	  -message => "The perl module 'POSIX' is missing"
	);
	die;
    }
    if (is_in_path("pod2man") && is_in_path("groff")) {
	my $gv = is_in_path("gv") || is_in_path("ghostview") || is_in_path("XXXggv") || is_in_path("kghostview");
	if ($gv) {
	    my $temp = POSIX::tmpnam();
	    # XXX $temp is never deleted...
	    system("pod2man $path | groff -man -Tps > $temp");
	    system("$gv $temp &");
	    return;
	}
    }
    $w->messageBox(
      -title   => "Tk::Pod Error",
      -message => "Can't print on your system.\nEither pod2man, groff,\ngv or ghostview are missing."
    );
    die;
}

sub Print_MSWin {
  my($self, $path) = @_;
  my $is_old;
  $is_old = 1  if
   defined(&Win32::GetOSVersion) and
   eval {require Win32; 1} and
   defined(&Win32::GetOSName) and
    (Win32::GetOSName() eq 'Win32s'  or   Win32::GetOSName() eq 'Win95');
  require POSIX;

  my $temp = POSIX::tmpnam(); # XXX it never gets deleted
  $temp =~ tr{/}{\\};
  $temp =~ s/\.$//;
  DEBUG and print "Using $temp as the temp file for hardcopying\n";

  if($is_old) { # so we can't assume that write.exe can handle RTF
    require Pod::Simple::Text;
    require Text::Wrap;
    local $Text::Wrap::columns = 65; # reasonable number, I think.
    $temp .= '.txt';
    Pod::Simple::Text->parse_from_file($path, $temp);
    system("notepad.exe", "/p", $temp);

  } else { # Assume that our write.exe should understand RTF
    require Pod::Simple::RTF;
    $temp .= '.rtf';
    Pod::Simple::RTF->parse_from_file($path, $temp);
    system("write.exe", "/p", "\"$temp\"");
  }

  return;
}


# Return $first and $last indices of the word under $index
sub _word_under_index {
    my($w, $index)= @_;
    my ($first,$last);
    $first = $w->search(qw/-backwards -regexp --/, '[^\w:]', $index, "$index linestart");
    $first = $w->index("$first + 1c") if $first;
    $first = $w->index("$index linestart") unless $first;
    $last  = $w->search(qw/-regexp --/, '[^\w:]', $index, "$index lineend");
    $last  = $w->index("$index lineend") unless $last;
    ($first, $last);
}

sub SelectToModule {
    my($w, $index)= @_;
    my ($first,$last) = $w->_word_under_index($index);
    if ($first && $last) {
	$w->tagRemove('sel','1.0',$first);
	$w->tagAdd('sel',$first,$last);
	$w->tagRemove('sel',$last,'end');
	$w->idletasks;
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Add the file $file (with optional text index position $index) to the
# history.
sub history_add {
    my ($w,$file,$index) = @_;
    unless (-f $file) {
	$w->messageBox(-message => "Not a file '$file'. Can't add to history\n",
		       @{&HISTORY_DIALOG_ARGS});
	return;
    }
    my $hist = $w->privateData()->{history};
    my $hist_entry = _HistoryEntry->create($file, $index);
    $hist->[++$w->privateData()->{history_index}] = $hist_entry;
    splice @$hist, $w->privateData()->{history_index}+1;
    $w->history_view_update;
    $w->history_view_select;
    undef;
}

# Perform a "history back" operation, if possible. The current page is
# updated in the history.
sub history_back {
    my ($w) = @_;
    my $hist = $w->privateData()->{history};
    if (!@$hist) {
        $w->messageBox(-message => "History is empty",
		       @{&HISTORY_DIALOG_ARGS});
	return;
    }
    if ($w->privateData()->{history_index} <= 0) {
	$w->messageBox(-message => "Can't go back",
		       @{&HISTORY_DIALOG_ARGS});
	return;
    }

    $w->history_modify_entry;

    $hist->[--$w->privateData()->{history_index}];
}

# Perform a "history forward" operation, if possible. The current page is
# updated in the history.
sub history_forward {
    my ($w) = @_;
    my $hist = $w->privateData()->{history};
    if (!@$hist) {
        $w->messageBox(-message => "History is empty",
		       @{&HISTORY_DIALOG_ARGS});
	return;
    }
    if ($w->privateData()->{history_index} >= $#$hist) {
	$w->messageBox(-message => "Can't go forward",
		       @{&HISTORY_DIALOG_ARGS});
	return;
    }

    $w->history_modify_entry;

    $hist->[++$w->privateData()->{history_index}];
}

# Private method: update the pod view if called from a history back/forward
# operation. This method will set the specified _HistoryEntry object.
sub _history_update {
    my($w, $hist_entry) = @_;
    if ($hist_entry) {
	if ($w->cget('-path') ne $hist_entry->file) {
	    $w->privateData()->{'from_history'} = 1;
	    $w->configure('-file' => $hist_entry->file);
	    $w->privateData()->{'from_history'} = 0;
	}
	$w->afterIdle(sub { $w->see($hist_entry->index) })
	    if $hist_entry->index;
    }
}

# Move the history backward ($inc == -1) or forward ($inc == +1)
sub history_move {
    my($w, $inc) = @_;
    my $hist_entry = ($inc == -1 ? $w->history_back : $w->history_forward);
    $w->_history_update($hist_entry);
    $w->history_view_select;
}

# Set the history to the given index $inx.
sub history_set {
    my($w, $inx) = @_;
    if ($inx >= 0 && $inx <= $#{$w->privateData()->{history}}) {
	$w->history_modify_entry;
	$w->privateData()->{history_index} = $inx;
	$w->_history_update($w->privateData()->{history}->[$inx]);
    }
}

# Modify the index (position) information of the current history entry.
sub history_modify_entry {
    my $w = shift;
    if ($w->privateData()->{'history_index'} >= 0) {
	my $old_entry = _HistoryEntry->create($w->cget('-path'),
					      $w->index('@0,0'));
	$w->privateData()->{'history'}->[$w->privateData()->{'history_index'}] = $old_entry;
    }
}

# Create a new history view toplevel or reuse an old one.
sub history_view {
    my $w = shift;
    my $t = $w->privateData()->{'history_view_toplevel'};
    if (!$t || !Tk::Exists($t)) {
	$t = $w->Toplevel(-title => 'History');
	$t->transient($w);
	$w->privateData()->{'history_view_toplevel'} = $t;
	my $lb = $t->Scrolled("Listbox", -scrollbars => 'oso'.($Tk::platform eq 'MSWin32'?'e':'w'))->pack(-fill => "both", '-expand' => 1);
	$t->Advertise(Lb => $lb);
	$lb->bind("<1>" => sub {
		      my $lb = shift;
		      my $y = $lb->XEvent->y;
		      $w->history_set($lb->nearest($y));
		  });
    }
    $t->deiconify;
    $t->raise;
    $w->history_view_update;
}

# Re-fill the history view with the current history array.
sub history_view_update {
    my $w = shift;
    my $t = $w->privateData()->{'history_view_toplevel'};
    if ($t && Tk::Exists($t)) {
	my $lb = $t->Subwidget('Lb');
	$lb->delete(0, "end");
	foreach my $histentry (@{$w->privateData()->{'history'}}) {
	    (my $basename = $histentry->file) =~ s|^.*/([^/]+)$|$1|;
	    $lb->insert("end", $basename);
	}
    }
}

# Move the history view selection to the current selected history entry.
sub history_view_select {
    my $w = shift;
    my $t = $w->privateData()->{'history_view_toplevel'};
    if ($t && Tk::Exists($t)) {
	my $lb = $t->Subwidget('Lb');
	$lb->selectionClear(0, "end");
	$lb->selectionSet($w->privateData()->{history_index});
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository
# REPO MD5 1b42243230d92021e6c361e37c9771d1

sub is_in_path {
    my($prog) = @_;
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe");
	} else {
	    return "$_/$prog" if (-x "$_/$prog");
	}
    }
    undef;
}
# REPO END

sub is_interactive {
    if ($^O eq 'MSWin32' || !eval { require POSIX; 1 }) {
	# fallback
	return -t STDIN && -t STDOUT;
    }

    # from perlfaq8
    open(TTY, "/dev/tty") or die $!;
    my $tpgrp = POSIX::tcgetpgrp(fileno(*TTY));
    my $pgrp = getpgrp();
    if ($tpgrp == $pgrp) {
	1;
    } else {
	0;
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

=head1 ENVIRONMENT

=over

=item TKPODDEBUG

Turn debugging mode on if set to a true value.

=item TKPODPRINT

Use the specified program for printing the current pod. If the string
contains a C<%s>, then filename substitution is used, otherwise the
filename of the POD document is appended to the value of
C<TKPODPRINT>. Here is a silly example to send the POD to a web browser:

    env TKPODPRINT="pod2html %s > %s.html; galeon %s.html" tkpod ...

=head1 SEE ALSO

L<Tk::More|Tk::More>
L<Tk::Pod|Tk::Pod>
L<Tk::Pod::SimpleBridge|Tk::Pod::SimpleBridge>
L<Tk::Pod::Styles|Tk::Pod::Styles>
L<Tk::Pod::Search|Tk::Pod::Search>
L<Tk::Pod::Search_db|Tk::Pod::Search_db>
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

=item auml: E<auml> ä,

=item Auml: E<Auml> Ä,

=item ouml: E<ouml> ö,

=item Ouml: E<Ouml> Ö,

=item Uuml: E<uuml> ü,

=item Uuml: E<Uuml> Ü,

=item sz: E<szlig> ß.

=back

Pod with Umlaut: L<ExtUtils::MakeMaker> and ExtUtils::MakeMaker.

Details:  L<perlpod> or perl, perlfunc.

Here some code in a as is paragraph

    use Tk;
    my $mw = MainWindow->new;
    ...
    MainLoop
    __END__


Fonts: C<fixed>, B<bold>, I<italics>, normal, or file
F</path/to/a/file>

Mixed Fonts: B<C<bold-fixed>>, B<I<bold-italics>>

Non-breakable text: S<The quick brown fox jumps over the lazy fox.>

Other POD docu: Tk::Font, Tk::BrowseEntry

=head1 AUTHOR

Nick Ing-Simmons <F<nick@ni-s.u-net.com>>

Current maintainer is Slaven Rezic <F<slaven.rezic@berlin.de>>.

Copyright (c) 1998 Nick Ing-Simmons.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

