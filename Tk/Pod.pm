package Tk::Pod;
use strict;
use Tk::Toplevel;

use vars qw($VERSION @ISA);
$VERSION = substr(q$Revision: 1.6 $, 10)+ 1; # so it's > 2.005

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
 $file->pack('-side' => 'left','-anchor' => 'w');
 $file->command('-label'=>'Open...', '-underline'=>0, '-command' => ['openfile',$w]);
 $file->command('-label'=>'Re-Read', '-underline'=>0, '-command' => ['reload',$p] );
 $file->command('-label'=>'Edit',    '-underline'=>0, '-command' => ['edit',$p] );
 $file->separator;
 $file->command('-label'=>'Quit',    '-underline'=>0, '-command' => ['quit',$w] );

 my $help = $mbar->Component('Menubutton' => 'help', '-text' => 'Help', '-underline' => 0);
 $help->pack('-side' => 'right','-anchor' => 'e');
 # xxx restructure to not reference to tkpod
 $help->command('-label' => 'Usage...',       -command => sub{$w->parent->Pod(-file=>'tkpod')} );
 $help->command('-label' => 'Programming...', -command => sub{$w->parent->Pod(-file=>'Tk/Pod.pm')} );

 $mbar->pack('-side' => 'top', '-fill' => 'x', '-before' => ($w->packSlaves)[0]);
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

tkpod, Tk::Pod::Text, perlpod

=cut

