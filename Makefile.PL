use ExtUtils::MakeMaker;

require Tk;
if ($Tk::VERSION eq '800.003')
  {
    print <<EOT;

        Uppps you're using the alpha release Tk V$Tk::VERSION:
        FileSelection of this perl/Tk release does not work
        (was my fault!).  So 'Open...' menu entry will not work
	with Tk800.003

EOT
  }

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk' => 402.000, 'Text::English' => 0 },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk::Pod',
	'VERSION'	=> 0.09,

	'DIR'		=> [],	# Tk-Pod dist build dir is ignored

	'EXE_FILES'	=> [ 'tkpod' ],

        'dist'		=> {'COMPRESS'=>'gzip -9f', 'SUFFIX'=>'.gz'}, 
);
