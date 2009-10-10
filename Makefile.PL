# -*- perl -*-

use ExtUtils::MakeMaker;

$DIST_VERSION = "0.9939_56";
$is_devel_host = defined $ENV{USER} && $ENV{USER} eq 'eserte' && $^O =~ /bsd/i && -f "../../perl.release.mk";
if ($is_devel_host) {
    open(P, "Pod.pm") or die "Can't open Pod.pm: $!";
 SEARCH_FOR_DIST_VERSION: {
	while(<P>) {
	    if (/DIST_VERSION\s*=\s*["'](.*)["']/) {
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
	my $meta_schema = "../Kwalify/t/testdata/META-spec-1.3.yml";
	if (is_in_path("pkwalify") && -f $meta_schema) {
	    system("pkwalify", "-f", $meta_schema, "META.yml");
	    if ($? != 0) {
		die "Cannot validate META.yml against $meta_schema";
	    }
	} else {
	    warn "Prerequisites for validating META.yml are missing";
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

if ($] < 5.009003) {
    warn <<EOF;
**********************************************************************
* Warnings looking like
*    Unknown escape E<0x107>
* are expected and may be ignored.
**********************************************************************
EOF
}

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk'             => 800.004,
			     'Pod::Simple'    => 2.05, # there at least in 2.03 bugs when processing "-f ..." output
			     'File::Temp'     => 0,
			     'File::Spec'     => 0,
			     # the following are really only COREQUISITES
	                     'Text::English'  => 0,
			     'Tk::HistEntry'  => 0.40,
			     # Very very optional Corequisites
			     # 'Tk::WidgetDump' => 0,
			     # 'Module::Refresh' => 0,
			     %add_prereq_pm,
			   },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> $DIST_VERSION,
	'NO_META'	=> 1, # manually generated
	'LICENSE'	=> 'perl',

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod', 'tkmore' ],

	'dist' 		=> {'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)',
			    # http://rt.cpan.org/Ticket/Display.html?id=29664
			    $is_devel_host ? ('PREOP'=>'test -w META.yml || (echo "META.yml has to be writable"; false)') : (),
			   },
);

# This rule ensures that we get UNKNOWN test results on Unix platforms
# if no X11 DISPLAY is available. This does not apply for cygwin/X11;
# the display test there is done in the test files using
# TkTest::display_test
sub MY::test_via_harness {
    my($self, $perl, $tests) = @_;
    qq{\t$perl "-It" "-MTkTest" }.
	qq{"-e" "check_display_test_harness(\$(TEST_VERBOSE), '\$(INST_LIB)', '\$(INST_ARCHLIB)')" $tests\n};
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
	    BEGIN { print "# DO NOT EDIT\n# Created by the update-WWWBrowser makefile rule\n\n# DO NOT USE THIS MODULE IN YOUR PROJECTS\n# (That is, the module\047s code is OK, but don\047t rely on the package\n# name or the API of this module)" } \
	    s{package WWWBrowser}{package # hide from PAUSE indexer\n\tTk::Pod::WWWBrowser}; \
	    s{package Launcher::WWW}{package # hide from PAUSE indexer\n\tTk::Pod::Launcher::WWW}; \
	    if (m{#.*Forward compatibility}) { \
		$$skip_forward_compat++; \
	    } elsif ($$skip_forward_compat && m|^}|) { \
		$$skip_forward_compat = 0; next; \
	    } \
	    if (m{__END__}) { \
		$$do_not_print++; \
	    } \
	    print if (!$$do_not_print && !$$skip_forward_compat); \
	    ' \
	    < ../../perl/WWWBrowser/WWWBrowser.pm > Pod/WWWBrowser.pm~
	    perl -c Pod/WWWBrowser.pm~
	    mv Pod/WWWBrowser.pm~ Pod/WWWBrowser.pm

EOF
    }

    $postamble;
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/work/srezic-repository 
# REPO MD5 c9844dc5bfa1798245e913b3e53ba4e1

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    %Config::Config = %Config::Config if 0; # cease -w
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/work/srezic-repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

