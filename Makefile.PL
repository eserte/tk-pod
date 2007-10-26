# -*- perl -*-

use ExtUtils::MakeMaker;

$DIST_VERSION = "0.9936";
$is_devel_host = defined $ENV{USER} && $ENV{USER} eq 'eserte' && $^O =~ /bsd/i && -f "../../perl.release.mk";
if ($is_devel_host) {
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

    if (!eval { require YAML; 1 }) {
	warn "Please install YAML, otherwise no META.yml check could be done!";
    } else {
	my $meta = YAML::LoadFile("META.yml");
	if ($meta->{version} ne $DIST_VERSION) {
	    die "Please fix version in META.yml!\n";
	}
    }
}

my %add_prereq_pm;
if (eval { require Tk::Tree; 1 } && $Tk::Tree::VERSION eq '4.6') {
    warn <<EOF;
**********************************************************************
* You have Tk::Tree $Tk::Tree::VERSION, which is broken.
**********************************************************************
EOF
    $add_prereq_pm{"Tk::Tree"} = "4.7";
}

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk'             => 800.004,
			     'Pod::Simple'    => 2.05, # there at least in 2.03 bugs when processing "-f ..." output
			     'File::Temp'     => 0,
			     'File::Spec'     => 0,
			     # the following are really only COREQUISITES
	                     'Text::English'  => 0,
			     'Tk::HistEntry'  => 0.40,
			     %add_prereq_pm,
			   },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> $DIST_VERSION,
	'NO_META'	=> 1, # manually generated
	'LICENSE'	=> 'perl',

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod', 'tkmore' ],

	'dist' 		=> {'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)'},
);

sub MY::test_via_harness {
    my($self, $perl, $tests) = @_;
    qq{\t$perl "-It" "-MTkTest" "-MExtUtils::Command::MM" }.
	qq{"-e" "check_display_harness; test_harness(\$(TEST_VERBOSE), '\$(INST_LIB)', '\$(INST_ARCHLIB)')" $tests\n};
}

sub MY::postamble {
    my $postamble = <<'EOF';
demo :: pure_all
	$(FULLPERL) -w -Mblib $(INST_SCRIPT)$(DFSEP)tkpod -tree -nodebug

EOF

    if ($is_devel_host) {
	$postamble .= <<'EOF';

.include "../../perl.release.mk"
.include "../../perl.cvs.mk"

update-WWWBrowser:
	perl -nle '\
	    BEGIN { print "# DO NOT EDIT\n" } \
	    BEGIN { print "# DO NOT USE THIS MODULE IN YOUR PROJECTS\n" } \
	    s{package WWWBrowser}{package # hide from PAUSE indexer\n\tTk::Pod::WWWBrowser}; \
	    s{package Launcher::WWW}{package # hide from PAUSE indexer\n\tTk::Pod::Launcher::WWW}; \
	    if (m{__END__}) { \
		$$do_not_print++; \
	    } \
	    print if (!$$do_not_print); \
	    ' \
	    < ../../perl/WWWBrowser/WWWBrowser.pm > Pod/WWWBrowser.pm

EOF
    }

    $postamble;
}
