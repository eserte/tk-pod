# -*- perl -*-

#
# $Id: FindPods.pm,v 2.8 2003/11/09 21:14:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Pod::FindPods;

=head1 NAME

Tk::Pod::FindPods - find Pods installed on the current system


=head1 SYNOPSIS

    use Tk::Pod::FindPods;

    my $o = Tk::Pod::FindPods->new;
    $pods = $o->pod_find(-categorized => 1, -usecache => 1);

=head1 DESCRIPTION

=cut

use base 'Exporter';
use strict;
use vars qw($VERSION @EXPORT_OK $init_done %arch $arch_re);

@EXPORT_OK = qw/%pods $has_cache pod_find/;

$VERSION = sprintf("%d.%02d", q$Revision: 2.8 $ =~ /(\d+)\.(\d+)/);

BEGIN {  # Make a DEBUG constant very first thing...
  if(defined &DEBUG) {
  } elsif(($ENV{'TKPODDEBUG'} || '') =~ m/^(\d+)/) { # untaint
    my $debug = $1;
    *DEBUG = sub () { $debug };
  } else {
    *DEBUG = sub () {0};
  }
}

use File::Find;
use File::Spec;
use File::Basename;
use Config;

sub new {
    my($class) = @_;
    my $self = bless {}, $class;
    $self->init;
    $self;
}

sub init {
    return if $init_done;
    %arch = guess_architectures();
    $arch_re = "(" . join("|", map { quotemeta $_ } ("mach", keys %arch)) . ")";
    $init_done++;
}

=head2 pod_find

The B<pod_find> method scans the current system for available Pod
documentation. The keys of the returned hash reference are the names
of the modules or Pods (C<::> substituted by C</> --- this makes it
easier for Tk::Pod::Tree, as the separator may only be of one
character). The values are the corresponding filenames.

If C<-categorized> is specified, then the returned hash has an extra
level with four categories: B<perl> (for core language documentation),
B<pragma> (for pragma documentation like L<var|var> or
L<strict|strict>), B<mod> (core or CPAN modules), and B<script> (perl
scripts with embedded Pod documentation). Otherwise, C<-category> may
be set to force the Pods into a category.

By default, C<@INC> is scanned for Pods. This can be overwritten by
the C<-directories> option (specify as an array reference).

If C<-usecache> is specified, then the list of Pods is cached in a
temporary directory. C<-usecache> is disabled if C<-categorized> is
not set or C<-directorties> is set.

=cut

sub pod_find {
    my $self = shift;
    my(@args) = @_;
    my %args;
    if (ref $args[0] eq 'HASH') {
	%args = %{ $args[0] };
    } else {
	%args = @args;
    }

    $self->{has_cache} = 0;

    if ($args{-usecache}) {
	if (!$args{-categorized} || $args{-directories}) {
	    DEBUG and warn "Disabling -usecache";
	} else {
	    my $perllocal_site = File::Spec->catfile($Config{'installsitearch'},'perllocal.pod');
	    my $perllocal_lib  = File::Spec->catfile($Config{'installarchlib'},'perllocal.pod');
	    my $cache_file = _cache_file();
	    if (-r $cache_file &&
		(-e $perllocal_site && -M $perllocal_site > -M $cache_file) &&
		(-e $perllocal_lib  && -M $perllocal_lib > -M $cache_file)
	       ) {
		$self->LoadCache;
		if ($self->{pods}) {
		    $self->{has_cache} = 1;
		    return $self->{pods};
		}
	    } else {
		DEBUG and warn "$perllocal_site and/or $perllocal_lib are more recent than cache file $cache_file or cache file does not exist\n";
	    }
	}
    }

    my(@dirs, @script_dirs);
    if ($args{-directories}) {
	@dirs = @{ $args{-directories} };
	@script_dirs = ();
    } else {
	@dirs = grep { $_ ne '.' } @INC; # ignore current directory
	@script_dirs = ($Config{'scriptdir'});
    }

    my %seen_dir = ();
    my $curr_dir;
    undef $curr_dir;
    my %pods = ();

    if ($args{-category}) {
	$pods{$args{-category}} = {};
    }

    my $wanted = sub {
	if (-d) {
	    if ($seen_dir{$File::Find::name}) {
		$File::Find::prune = 1;
		return;
	    } else {
		$seen_dir{$File::Find::name}++;
	    }
	}

	if (-f && /\.(pod|pm)$/) {
	    my $curr_dir_rx = quotemeta $curr_dir;
	    (my $name = $File::Find::name) =~ s|^$curr_dir_rx/?||;
	    $name = simplify_name($name);

	    my $hash;
	    if ($args{-categorized}) {
		my $type = type($name);
		$hash = $pods{$type} || do { $pods{$type} = {} };
	    } elsif ($args{-category}) {
		$hash = $pods{$args{-category}};
	    } else {
		$hash = \%pods;
	    }

	    if (exists $hash->{$name}) {
		if ($hash->{$name} =~ /\.pod$/ && $File::Find::name =~ /\.pm$/) {
		    return;
		}
		my($ext1) = $hash->{$name}    =~ /\.(.*)$/;
		my($ext2) = $File::Find::name =~ /\.(.*)$/;
		if ($ext1 eq $ext2) {
		    warn "Clash: $hash->{$name} <=> $File::Find::name";
		    return;
		}
	    }
	    $hash->{$name} = "file:" . $File::Find::name;
	}
    };

    my $wanted_scripts = sub {
	if (-d) {
	    if ($seen_dir{$File::Find::name}) {
		$File::Find::prune = 1;
		return;
	    } else {
		$seen_dir{$File::Find::name}++;
	    }
	}

	if (-T && open(SCRIPT, $_)) {
	    my $has_pod = 0;
	    {
		local $_;
		while(<SCRIPT>) {
		    if (/^=(head\d+|pod)/) {
			$has_pod = 1;
			last;
		    }
		}
	    }
	    close SCRIPT;
	    if ($has_pod) {
		my $name = $_;

		my $hash;
		if ($args{-categorized}) {
		    my $type = 'script';
		    $hash = $pods{$type} || do { $pods{$type} = {} };
		} elsif ($args{-category}) {
		    $hash = $pods{$args{-category}};
		} else {
		    $hash = \%pods;
		}

		if (exists $hash->{$name}) {
		    return;
		}
		$hash->{$name} = "file:" . $File::Find::name;
	    }
	}
    };

    foreach my $inc (@dirs) {
	$curr_dir = $inc;
	find($wanted, $inc);
    }

    foreach my $inc (@script_dirs) {
	find($wanted_scripts, $inc);
    }

    $self->{pods} = \%pods;
    $self->{pods};
}

sub simplify_name {
    my $f = shift;
    $f =~ s|^\d+\.\d+\.\d+/?||; # strip perl version
    $f =~ s|^$arch_re|| if defined $arch_re; # strip machine
    $f =~ s/\.(pod|pm)$//;
    $f =~ s|^pod/||;
    # Workaround for case insensitive systems --- the pod directory contains
    # general pod documentation as well as Pod::* documentation:
    if ($^O =~ /^cygwin/) {
	$f =~ s|^pods/||; # "pod" is "pods" on cygwin
    } elsif ($^O eq 'MSWin32') {
	$f =~ s|^pod/perl|perl|i;
	$f =~ s|^pod/Win32|Win32|i;
    }
    $f;
}

sub type {
    local $_ = shift;
    if    (/^perl/) { return "perl" }
    elsif (/^[a-z]/ && !/^(mod_perl|lwpcook|lwptut|cgi_to_mod_perl|libapreq)/)
	            { return "pragma" }
    else            { return "mod" }
}

sub guess_architectures {
    my %arch;
    my @configs;
    foreach my $inc (@INC) {
	push @configs, glob("$inc/*/Config.pm");
    }
    foreach my $config (@configs) {
	my($arch) = $config =~ m|/([^/]+)/Config.pm|;
	if (open(CFG, $config)) {
	    while(<CFG>) {
		/archname.*$arch/ && do {
		    $arch{$arch}++;
		    last;
		};
	    }
	    close CFG;
	} else {
	    warn "cannot open $config: $!";
	}
    }
    %arch;
}

sub module_location {
    my $mod = shift;
    my($type, $path) = $mod =~ /^([^:]+):(.*)/;
    if ($type eq 'cpan') {
	'cpan';
    } elsif (is_site_module($path)) {
	'site';
    } else {
	'core';
    }
}

sub is_site_module {
    my $path = shift;
    if ($^O eq 'MSWin32') {
	return $path =~ m|[/\\]site[/\\]lib[/\\]|;
    }
    $path =~ /^(
                \Q$Config{'installsitelib'}\E
               |
		\Q$Config{'installsitearch'}\E
	       )/x;
}

sub _cache_file {
    (my $ver = $])                  =~ s/[^a-z0-9]/_/gi;
    (my $os  = $Config{'archname'}) =~ s/[^a-z0-9]/_/gi;
    my $uid  = $<;

    if (File::Spec->can('tmpdir')) {
        File::Spec->catfile(File::Spec->tmpdir, join('_', 'pods',$ver,$os,$uid));
      } else {
        File::Spec->catfile(($ENV{TMPDIR}||"/tmp"), join('_', 'pods',$ver,$os,$uid));
      }
}

sub pods      { shift->{pods} }
sub has_cache { shift->{has_cache} }

# Parts stolen from Pod::Perldoc::search_perlfunc
# Return pod text for given function
sub function_pod {
    my($self, $func) = @_;

    my $pod = "";

    my $perlfunc = $self->{pods}{perl}{perlfunc};
    $perlfunc =~ s{^file:}{};
    open(PFUNC, "< $perlfunc") or die "Can't open $perlfunc: $!";

    # Functions like -r, -e, etc. are listed under `-X'.
    my $search_re = ($func =~ /^-[rwxoRWXOeszfdlpSbctugkTBMAC]$/)
                        ? '(?:I<)?-X' : quotemeta($func) ;

    # Skip introduction
    local $_;
    while (<PFUNC>) {
        last if /^=head2 Alphabetical Listing of Perl Functions/;
    }

    # Look for our function
    my $found = 0;
    my $inlist = 0;
    while (<PFUNC>) {  # "The Mothership Connection is here!"
        if ( m/^=item\s+$search_re\W/ )  {
            $found = 1;
        }
        elsif (/^=item/) {
            last if $found > 1 and not $inlist;
        }
        next unless $found;
        if (/^=over/) {
            ++$inlist;
        }
        elsif (/^=back/) {
            --$inlist;
        }
        $pod .= $_;
        ++$found if /^\w/;        # found descriptive text
    }
    if ($pod eq "") {
        warn sprintf "No documentation for perl function `%s' found\n", $func;
    } else {
	# Fix pod so no warnings are given:
	$pod = "=over\n\n$pod\n\n=back\n";
    }
    close PFUNC                or die "Can't open $perlfunc: $!";

    return $pod;
}

=head2 WriteCache

Write the Pod cache. The cache is written to the temporary directory.
The file name is constructed from the perl version, operation system
and user id.

=cut

sub WriteCache {
    my $self = shift;

    require Data::Dumper;

    if (!open(CACHE, ">" . _cache_file())) {
	warn "Can't write to cache file " . _cache_file();
    } else {
	my $dd = Data::Dumper->new([$self->{pods}], ['pods']);
	$dd->Indent(0);
	print CACHE $dd->Dump;
	close CACHE;
    }
}

=head2 LoadCache()

Load the Pod cache, if possible.

=cut

sub LoadCache {
    my $self = shift;
    my $cache_file = _cache_file();
    if (-r $cache_file) {
	return if $< != (stat($cache_file))[4];
	require Safe;
	my $c = Safe->new('Tk::Pod::FindPods::SAFE');
	$c->rdo($cache_file);
	if (keys %$Tk::Pod::FindPods::SAFE::pods) {
	    $self->{pods} = { %$Tk::Pod::FindPods::SAFE::pods };
	    return $self->{pods};
	}
    }
    return {};
}

return 1 if caller;

package main;

require Data::Dumper;
print Data::Dumper->Dumpxs([{Tk::Pod::FindPods::pod_find(-categorized => 0, -usecache => 0)}],[]);

__END__

=head1 SEE ALSO

Tk::Tree(3).

=head1 AUTHOR

Slaven Rezic <F<slaven@rezic.de>>

Copyright (c) 2001,2003 Slaven Rezic.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
