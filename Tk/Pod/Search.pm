package Tk::Pod::Search;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = substr q$Revision: 1.2 $, 10;

use Carp;
use Tk::Frame;

Construct Tk::Widget 'PodSearch';
@ISA = 'Tk::Frame';


#sub ClassInit {
#    my ($class,$mw) = @_;
#
#}

sub Populate {
    my ($cw, $args) = @_;

    require Tk::Listbox;
    require Tk::Label;
    require Tk::BrowseEntry;

    my $l = $cw->Scrolled('Listbox',-scrollbars=>'w');
    #xxx BrowseEntry V1.3 does not honour -label at creation time :-(
    #my $e = $cw->BrowseEntry(-labelPack=>[-side=>'left'],-label=>'foo',
	#-listcmd=> ['_logit', 'list'],
	#-browsecmd=> ['_logit', 'browse'],
	#);
    my $e = $cw->BrowseEntry();
    my $s = $cw->Label();

    $l->pack(-fill=>'both', -side=>'top',  -expand=>1);
    $s->pack(-anchor => 'e', -side=>'left');
    $e->pack(-fill=>'x', -side=>'left', -expand=>1);

    $cw->Advertise( 'entry'	=> $e->Subwidget('entry')   );
    $cw->Advertise( 'listbox'	=> $l->Subwidget('listbox') );
    $cw->Advertise( 'browse'	=> $e);

    $cw->Delegates(
		'focus' => $cw->Subwidget('entry'),
		);

    $cw->ConfigSpecs(
		-label =>	[{-text=>$s}, 'label',    'Label',    'Search:'],
		-indexdir =>	['PASSIVE',   'indexDir', 'IndexDir', undef],
		-command =>	['CALLBACK',  undef,      undef,      undef],
		-search =>	['METHOD',    'search',   'Search',   ""],
		'DEFAULT' =>	[ $cw ],
		);

    $cw->Subwidget('listbox')->bind('<Double-1>', [\&_load_pod, $cw]);
    $cw->Subwidget('entry')->bind('<Return>',[\&_search,$cw,$l]);

    undef;
}

sub addHistory {
    my ($w, $obj) = @_;
    $w->Subwidget('browse')->insert(0,$obj);
}

sub _logit { print "logit=|", join('|',@_),"|\n"; }

sub search {
    my $cw = shift;
    my $e = $cw->Subwidget('entry');
    if (@_) {
	my $search = shift;
	$search = join(' ', @$search) if ref($search) eq 'ARRAY';
        $e->delete(0,'end');
        $e->insert(0,$search);
        return undef;
    } else {
	return $e->get;
    }
}

sub _load_pod {
    my $l = shift;
    my $cw = shift;

    my $pod = pretty2path( $l->get(($l->curselection)[0]));

    $cw->Callback('-command', $pod);
}


sub _search {
    my $e = shift;
    my $w = shift;
    my $l = shift;

    my $find = $e->get;

    require Tk::Pod::Search_db;

    #xxx: always open/close DBM files???
    my $idx = Tk::Pod::Search_db->new($w->{Configure}{-indexdir});	
    my @hits = $idx->searchWords($find);
    if (@hits) {
	$l->delete(0,'end');
        while (@hits) {
	    $l->insert('end', sprintf("%6.3f  %s", shift @hits,
			 path2pretty($idx->prefix . '/'. shift(@hits)) )
			);
        }
	$l->see(0);
	$l->activate(0);
    } else {
	croak "No POD documentation in Library matches: '$find'";
    }
}

# Converts  /where/ever/it/it/Mod/Sub/Name.pm
# to	    Mod/Sub/Name.pm   (/where/ever/it/is)
# and vice versa.  Assumes that module subdirectories
# start with an upper case char. (xxx: Better solution
# when perlindex gives more infos.

sub path2pretty {
    my @path = split '/', shift, -1; 
#    shift @path if $path[0] eq "";	# due to leading /
    my $pretty = pop(@path);
    while (@path) {
        last if $path[-1] !~ /^[A-Z]/;
	$pretty = pop(@path) . '/' . $pretty;
    }
    #xxx is there a min 40c_or_more format directive?
    sprintf "%-40s (%s)", $pretty, join('/',@path);
}

sub pretty2path {
    local($_) = shift;
    /([^\s]+) \s+\( (.*) \)/x;
    $2 . '/' . $1;
}

#$path = '/where/ever/it/is/Tk/Pod.pm';	print "orig|",$path, "|\n";
#$nice = path2pretty $path;		print "nice|",$nice, "|\n";
#$path =  pretty2path $nice;		print "path|",$path, "|\n";


1;
__END__

=head1 NAME

Tk::Pod::Search - Widget to access perlindex POD full text index

=for section General Purpose Widget

=head1 SYNOPSIS

    use Tk::Pod::Search;
    ...
    $widget = $parent->PodSearch( ... );
    ...
    $widget->configure( -search => WORDS_TO_SEARCH );


=head1 DESCRIPTION

GUI interface to the full POD text indexer B<perlindex>.

=head1 OPTIONS

=over 4

=item B<Class:> Search

=item B<Member:> search

=item B<Option:> -search

Expects a list of words (or a whitespace seperated list).

=item B<Class:> undef

=item B<Member:> undef

=item B<Option:> -command

Defines a call back that is called when the use selects
a POD file. It gets the full path name of the POD file
as argument.

=back


=head1 METHODS

=over 4

=item I<$widget>->B<method1>I<(...,?...?)>

=back


=head1 SEE ALSO

Tk::Pod::Text, tkpod, perlindex, Tk::Pod, Tk::Parse, Tk::Pod::Search_db

=head1 KEYWORDS

widget, tk, pod, search, full text

=head1 AUTHOR

Achim Bohnet <F<ach@mpe.mpg.de>>

Copyright (c) 1997 Achim Bohnet. All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

