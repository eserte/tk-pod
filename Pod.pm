package Tk::Pod;
use strict;
use Tk::Toplevel;

use vars qw($VERSION @ISA);
$VERSION = substr(q$Revision: 1.13 $, 10) + 2; # so it's > 2.005 and 1.9+1

@ISA = qw(Tk::Toplevel);

Construct Tk::Widget 'Pod';

sub Populate
{
 my ($w,$args) = @_;

 require Tk::Pod::Text;
 require Tk::Menubar;

 $w->SUPER::Populate($args);
 my $p = $w->Component('PodText' => 'pod')->pack(-expand => 1, -fill => 'both');

 my $mbar = $w->Component('Menubar' => 'menubar');
 my $file = $mbar->Component('Menubutton' => 'file', '-text' => 'File', '-underline' => 0);
 $file->command('-label'=>'Open...', '-underline'=>0, '-command' => ['openfile',$w]);
 $file->command('-label'=>'Re-Read', '-underline'=>0, '-command' => ['reload',$p] );
 $file->command('-label'=>'Edit',    '-underline'=>0, '-command' => ['edit',$p] );
 $file->separator;
 $file->command('-label'=>'Close',    '-underline'=>0, '-command' => ['quit',$w] );

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
 $w->ConfigSpecs('DEFAULT' => [$p]);

 # $w->process($path);
 $w->protocol('WM_DELETE_WINDOW',['quit',$w]);
}

my $fsbox;

sub openfile {
    my ($cw,$p) = @_;
    unless (defined $fsbox && $fsbox->IsWidget) {
	require Tk::FileSelect;
	$fsbox = $cw->FileSelect();
    } 
    my $file = $fsbox->Show();
    $cw->configure(-file => $file) if defined $file && -r $file;
}
	
sub Dir { require Tk::Pod::Text; Tk::Pod::Text::Dir(@_) } 


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
                                    -underline => 0);
    }
    my $podtext = $pod->Subwidget('pod');
    my $text;
    foreach ($pod->{'SubWidget'}{'pod'}
             ->children->{'SubWidget'}{'more'}->children) {
        if ($_->isa('Tk::Text')) {
            $text = $_;
            last;
        }
    }

    $text->tag('configure', 'section',
               -background => 'red',
               -foreground => 'black',
              );

    my $sdef;
    foreach $sdef (@{$podtext->{'sections'}}) {
        my($head, $subject, $pos) = @$sdef;
        $section->command(-label => ("  " x ($head-1)) . $subject,
                          -command => sub {
                              my($line) = split(/\./, $pos);
                              $text->tag('remove', 'section', qw/0.0 end/);
                              $text->tag('add', 'section',
                                         $line-1 . ".0",
                                         $line-1 . ".0 lineend");
                              $text->yview("section.first");
			      $text->after(500, [$text, qw/tag remove section 0.0 end/]);
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
		-file = > $name		# search and display POD for name
		);


=head1 DESCRIPTION

Simple POD browser with hypertext capabilities in a C<Toplevel> widget


=head1 SEE ALSO

L<Tk::Pod_usage|Tk::Pod_usage>
L<Tk::Pod::Text|Tk::Pod::Text>
L<tkpod|tkpod>
L<perlpod|perlpod>

=cut

