# -*- perl -*-

#
# $Id: FindPods.pm,v 1.2 2001/06/17 19:31:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Pod::FindPods;
use strict;
use vars qw($VERSION
	    $init_done %pods %arch $arch_re %seen_dir $curr_dir %args);

$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use File::Find;

sub init {
    %arch = guess_architectures();
    $arch_re = "(" . join("|", map { quotemeta $_ } ("mach", keys %arch)) . ")";
    #warn $arch_re;
    $init_done++;
}

sub pod_find {
    my(@args) = @_;
    if (ref $args[0] eq 'HASH') {
	%args = %{ $args[0] };
    } else {
	%args = @args;
    }

    init() unless $init_done;

    %seen_dir = ();
    undef $curr_dir;
    %pods = ();

    foreach my $inc (@INC) {
	$curr_dir = $inc;
	find(\&wanted, $inc);
    }

    %pods;
}

sub wanted {
    if (-d) {
	if ($seen_dir{$File::Find::name}) {
	    $File::Find::prune = 1;
	    return;
	} else {
	    $seen_dir{$File::Find::name}++;
	}
    }

    if (-f && /\.(pod|pm)$/) {
	(my $name = $File::Find::name) =~ s|^$curr_dir/?||;
	$name = simplify_name($name);

	my $hash;
	if ($args{-categorized}) {
	    my $type = type($name);
	    $hash = $pods{$type} || do { $pods{$type} = {} };
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
	$hash->{$name} = $File::Find::name;
    }
}

sub simplify_name {
    my $f = shift;
    $f =~ s|^\d+\.\d+\.\d+/?||; # strip perl version
    $f =~ s|^$arch_re|| if defined $arch_re; # strip machine
    $f =~ s/\.(pod|pm)$//;
    $f =~ s|^pod/||;
    $f;
}

sub type {
    local $_ = shift;
    if    (/^perl/) { return "perl" }
    elsif (/^[a-z]/ && !/^(mod_perl|lwpcook|cgi_to_mod_perl)/) { return "pragma" }
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

sub is_site_module {
    my $path = shift;
    require Config;
    $path =~ /^(
                $Config::Config{'installsitelib'}
               |
		$Config::Config{'installsitearch'}
	       )/x;
}

return 1 if caller;

package main;

require Data::Dumper;
print Data::Dumper->Dumpxs([{Tk::Pod::FindPods::pod_find(-categorized => 0)}],[]);

__END__
