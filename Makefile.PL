use ExtUtils::MakeMaker;

require Tk;
if ($Tk::VERSION eq '800.003')
  {
    print <<EOT;

        Uppps you are using the alpha release Tk V$Tk::VERSION:
        FileSelection of this perl/Tk release does not work
        (was my fault!).  So 'Open...' menu entry will not work
	with Tk800.003

EOT
  }

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk' => 800, 'Text::English' => 0 },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> '0.99_07',

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod' ],

        'dist'		=> {'COMPRESS'=>'gzip -9', 'SUFFIX'=>'.gz'}, 
);

sub MY::postamble {
	if (defined $ENV{USER} && $ENV{USER} eq 'eserte') {
		<<'EOF';
release :: dist
	cpan-upload $(DISTVNAME).tar$(SUFFIX)

EOF
	}
}
