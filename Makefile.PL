use ExtUtils::MakeMaker;

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk'             => 800.004,
	                     'Text::English'  => 0,
			     'Pod::Simple'    => 0,
			   },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> '0.9914',

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod' ],

	'dist' 		=> {'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)'},
);

sub MY::postamble {
	if (defined $ENV{USER} && $ENV{USER} eq 'eserte') {
		<<'EOF';
release :: dist
	cpan-upload $(DISTVNAME).tar$(SUFFIX)

EOF
	}
}
