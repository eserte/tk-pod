# -*- perl -*-

use ExtUtils::MakeMaker;

$DIST_VERSION = "0.9928";
if (defined $ENV{USER} && $ENV{USER} eq 'eserte') {
    open(P, "Pod.pm") or die "Can't open Pod.pm: $!";
 SEARCH_FOR_DIST_VERSION: {
	while(<P>) {
	    if (/DIST_VERSION\s*=\s*\"(.*)\"/) {
		if ($DIST_VERSION ne $1) {
		    die "Please adjust DIST_VERSION in Makefile.PL";
		}
		last SEARCH_FOR_DIST_VERSION;
	    }
	}
	die "Cannot find DIST_VERSION definition in Pod.pm";
    }
}

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk'             => 800.004,
			     'Pod::Simple'    => 2.05, # there at least in 2.03 bugs when processing "-f ..." output
			     'File::Temp'     => 0,
			     # the following are really only COREQUISITES
	                     'Text::English'  => 0,
			     'Tk::HistEntry'  => 0.40,
			   },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> $DIST_VERSION,

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod', 'tkmore' ],

	'dist' 		=> {'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)'},
);

sub MY::postamble {
    my $postamble = <<'EOF';
demo :: pure_all
	$(FULLPERL) -w -Mblib tkpod -tree -nodebug

EOF

    if (defined $ENV{USER} && $ENV{USER} eq 'eserte' && $^O =~ /bsd/i && -f "../../perl.release.mk") {
	$postamble .= <<'EOF';

.include "../../perl.release.mk"
.include "../../perl.cvs.mk"

EOF
    }

    $postamble;
}
