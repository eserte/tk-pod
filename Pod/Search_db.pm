#AnyDBM handling from perlindex:
# NDBM_File as LAST resort

package AnyDBM_File;
use vars '@ISA';
@ISA = qw(DB_File GDBM_File SDBM_File ODBM_File NDBM_File) unless @ISA;
my $mod;
for $mod (@ISA) {
    last if eval "require $mod"
};

package Tk::Pod::Search_db;

use strict;
use vars qw($VERSION);

$VERSION = substr(q$Revision: 2.4 $, 10) . "";

use Carp;
use Fcntl;
use Text::English;
use Config;

(my $PREFIX = $Config::Config{prefix}) =~ y|\\|/|d;
(my $IDXDIR = $Config::Config{man1dir}) =~ s|/[^/]+$||;
$IDXDIR ||= $PREFIX; # use perl directory if no manual directory exists

sub new {
    my $class = shift;
    my $idir  = shift;

    $idir ||= $IDXDIR;

    my (%self, %IF, %IDF, %FN);
    tie (%IF,   'AnyDBM_File', "$idir/index_if",   O_RDONLY, 0644)
        	or confess "Could not tie $idir/index_if: $!\n".
            	"Did you run 'perlindex -index'?\n";
    tie (%IDF,  'AnyDBM_File', "$idir/index_idf",   O_RDONLY, 0644)
        	or confess "Could not tie $idir/index_idf: $!\n";
    tie (%FN,   'AnyDBM_File', "$idir/index_fn",   O_RDONLY, 0644)
        	or confess "Could not tie $idir/index_fn: $!\n";

    $self{IF}  = \%IF;
    $self{IDF} = \%IDF;
    $self{FN}  = \%FN;
    #xxx: -idir depended but where can I get this info?
    #	o A fourth index file?
    #   o todo: check perlindex index routine
    $self{PREFIX} = $PREFIX;

    bless \%self, $class;
}

# changes to perlindex's normalize
#	o removed useless(?) stemmer check
#	o lexicalized $word

sub normalize {
    my $line = join ' ', @_;
    my @result;

    $line =~ tr/A-Z/a-z/;
    $line =~ tr/a-z0-9/ /cs;

    my $word;
    for $word (split ' ', $line ) {
        $word =~ s/^\d+//;
        next unless length($word) > 2;
        push @result, &Text::English::stem($word);
    }
    @result;
}

# changes for perlindex's search slightly modified
sub searchWords {
    my $self = shift;

    #print "try words|", join('|',@_),"\n";
    my %score;
    my $maxhits = 15;
    my (@unknown, @stop);

    my $IF  = $self->{IF};
    my $IDF = $self->{IDF};
    my $FN  = $self->{FN};

    #xxx &initstop if $opt_verbose;
    my ($word, $did, %post); #xxx
    for $word (normalize(@_)) {
        unless ($IF->{$word}) {
            #xxxif ($stop{$word}) {
            #xxx    push @stop, $word;
            #xxx} else {
            #xxx    push @unknown, $word;
            #xxx}
            next;
        }
        #my %post = unpack($p.'*',$IF->{$word});
        %post = unpack('w*',$IF->{$word});
        my $idf = log($FN->{'last'}/$IDF->{$word});
        for $did (keys %post) {
            #xxx my ($maxtf) = unpack($p, $FN->{$did});
            my ($maxtf) = unpack('w', $FN->{$did});
            $score{$did} = 0 unless defined $score{$did}; # perl -w
            $score{$did} += $post{$did} / $maxtf * $idf;
        }
    }

    my @results;
    for $did (sort {$score{$b} <=> $score{$a}} keys %score) {
            my ($mtf, $path) = unpack('wa*', $FN->{$did});
            push @results, $score{$did}, $path;
            last unless --$maxhits;
    }

    #print "results|", join('|',@results),"\n";
    @results;
}

sub prefix {
    shift->{PREFIX};
}

1;
__END__

=head1 NAME

Tk::Pod::Search_db - dirty OO wrapper for C<perlindex>'s search functionality

=head1 SYNOPSIS

    ** THIS IS ALPHA SOFTWARE everything may and should change **
    **   stuff here is more a scratch pad than docomentation!  **

    use Tk::Pod::Search_db;
    ...
    $idx = Tk::Pod::Search_db->new?(INDEXDIR)?;
    ...
    @hits = $idx->searchWords(WORD1,...); # @hits is a list of
                                             # relpath1,score1,...  where
                                             # score is increasing
    $prefix = $idx->prefix();

    @word = Tk::Pod::Search_db::normalize(STRING1,...);

=head1 DESCRIPTION

Module to search POD documentation.  Before you can use
the module one should create the indices with C<perlindex -index>.

=head1 MISSING

Enable options like -maxhits (currently = 15).  Solve PREFIX
dependency.  Interface for @stop and @unknown also as methods
return lists for last searchWords call?

Lots more ...

=head1 METHODS

=over 4

=item $idx = Tk::Pod::Search_db->new(INDEXDIR)

Interface may change to support options like -maxhits

=item $idx->seachWords(WORD1?,...?)

search for WORD(s). Return a list of

  relpath1, score1, relpath2, score2, ...

or empty list if no match is found.

=item $pathprefix = $idx->pathprefix()

The return path prefix and C<$relpath> give together the full path
name of the POD documentation.

	$fullpath = $patchprefix . '/' . $relpath

B<Note:> Should make it easy to use Tk::Pod::Search with perlindex but
index specific prefix handling is a mess up to know.

=back

=head1 SEE ALSO

tkpod, perlindex perlpod, Tk::Pod::Search

=head1 AUTHORS

Achim Bohnet  <F<ach@mpe.mpg.de>>

Most of the code here is borrowed from L<perlindex> written by
Ulrich Pfeifer <F<Ulrich.Pfeifer@de.uu.net>>.

Current maintainer is Slaven Rezic <F<slaven@rezic.de>>.

Copyright (c) 1997-1998 Achim Bohnet. All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
