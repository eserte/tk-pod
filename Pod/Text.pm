package Tk::Pod::Text;

use strict;
use Carp;
use Config;
use Tk::Frame;
use Tk::Pod;
use Tk::Parse;

use vars qw($VERSION @ISA @POD $IDX);
$VERSION = substr(q$Revision: 3.7 $, 10) + 1 . "";
@ISA = qw(Tk::Frame);

Construct Tk::Widget 'PodText';

BEGIN { @POD = (@INC, grep(-d, split($Config{path_sep},
				     $ENV{'PATH'}))); $IDX = undef; };

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
    if ($name !~ /^[-_+:.\/A-Za-z0-9]+$/) {
	$w->messageBox(-message => "Invalid path/file/module name: '$name'\n");
	die;
    }
    Find($name) or do {
	$w->messageBox(-message => "Can't find POD Invalid file/module name: '$name'\n");
	die;
    };
}

sub file {
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
	  $tree_sw->SeePath($path);
      }
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
     $edit = $ENV{XEDITOR} || ($isatty
			       ? ($ENV{VISUAL} || $ENV{'EDITOR'} || 'vi')
			       : 'ptked');
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
    $p->menu($m);

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
       $w->messageBox(-message => "No POD documentation found for '$sel'\n");
       die;
   }
  }
 Tk->break;
}

sub Link
{
 my ($w,$how,$index,$link) = @_;

 # If clicking on a Link, the <Leave> binding is never called, so it
 # have to be done here:
 $w->LeaveLink;

 my($man,$sec) = ('','');

 if (eval { require Pod::ParseUtils; 1 })
  {
   my $l = Pod::Hyperlink->new($link);
   if ($l->type eq 'hyperlink')
    {
     if (eval { push @INC, "/home/e/eserte/lib/perl" if -d "/home/e/eserte/lib/perl"; require WWWBrowser; 1 }) # XXX bundle WWWBrowser with Tk::Pod
      {
       WWWBrowser::start_browser($l->node);
      }
     else
      {
       $w->messageBox(-message => 'Hyperlinks are not supported (yet)');
       die;
      }
     return;
    }
   $man = $l->page;
   $sec = $l->node;
  }
 else
  {
   warn "No Pod::ParseUtils installed, fallback...";
   $man = $link;
   ($man,$sec) = split(m|/|,$link) if ($link =~ m|/|);
   $man =~ s/::/\//g;
  }


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
   $w = $w->MainWindow->Pod('-file' => $man, '-tree' => $tree);
  }
  # XXX big docs like Tk::Text take too long until they return

 if ($sec ne '' && $man eq '') # XXX reuse vs. new`
  {
   $w->history_modify_entry;
  }

 if ($sec ne '')
  {
   my $start = ($w->tag('nextrange',$sec, '1.0'))[0];
   $start = ($w->tag('nextrange',"\"$link\"",'1.0'))[0] unless defined $start;
   $start = $w->search(qw/-exact -nocase --/, $sec, '1.0') unless defined $start;
   unless (defined $start)
    {
     $w->messageBox(-message => "Section '$sec' not found\n");
     die;
    }
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
	$w->messageBox(-message => "Cannot find file `$path`");
	die;
    }
    if (!eval { require POSIX; 1 }) {
	$w->messageBox(-message => "The perl module POSIX is missing");
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
    $w->messageBox(-message => "Can't print on your system.\nEither pod2man, groff,\ngv or ghostview are missing.");
    die;
}

sub SelectToModule {
    my($w, $index)= @_;
    my $cur = $w->index($index);
    my ($first,$last);
    $first = $w->search(qw/-backwards -regexp --/, '[^\w:]', $index, "$index linestart");
    $first = $w->index("$first + 1c") if $first;
    $first = $w->index("$index linestart") unless $first;
    $last  = $w->search(qw/-regexp --/, '[^\w:]', $index, "$index lineend");
    $last  = $w->index("$index lineend") unless $last;

    if ($first && $last) {
	$w->tagRemove('sel','1.0',$first);
	$w->tagAdd('sel',$first,$last);
	$w->tagRemove('sel',$last,'end');
	$w->idletasks;
    }
}

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
       $w->tag('bind',$tag, '<Enter>' => [$w, 'EnterLink']);
       $w->tag('bind',$tag, '<Leave>' => [$w, 'LeaveLink']);
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

 $line =~ s/E\x7f([A-Za-z]\w*)\x7f/$Tk::Parse::Escapes{$1}/g;
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

 my $process_no;
 $w->{ProcessNo}++;
 $process_no = $w->{ProcessNo};

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
       $arg =~ s/[IBSCLFXZ]<([^>]+)>/$1/g; # XXX better, but not perfect...
       $arg =~ s/\s+/ /g; # filter tabs etc.
       push @{$w->{'sections'}}, [$head, $arg, $w->index('end')];
   }
   $w->$cmd($arg);
   unless ($update--) {
     $w->update;
     $update = 2;
     do { warn "ABORT!"; return } if $w->{ProcessNo} != $process_no;
   }
  }
 $w->parent->add_section_menu if $w->parent->can('add_section_menu');
 $w->Callback('-poddone', $file);
 # set (invisible) insertion cursor to top of file
 $w->markSet(insert => '@0,0');
 $w->toplevel->Unbusy;
 @ARGV = @save;
}

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

Current maintainer is Slaven Rezic <F<slaven.rezic@berlin.de>>.

Copyright (c) 1998 Nick Ing-Simmons.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

