use ExtUtils::MakeMaker;

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk'             => 800.004,
			     'Pod::Simple'    => 0,
			     # the following are really only COREQUISITES
	                     'Text::English'  => 0,
			     'Tk::HistEntry'  => 0.40,
			   },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> '0.9915',

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod' ],

	'dist' 		=> {'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)'},
);

sub MY::postamble {
	if (defined $ENV{USER} && $ENV{USER} eq 'eserte') {
		<<'EOF';
release :: $(DISTVNAME).tar$(SUFFIX)
	cpan-upload $(DISTVNAME).tar$(SUFFIX)

EOF
	}
}
