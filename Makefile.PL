use ExtUtils::MakeMaker;

WriteMakefile(
	'PREREQ_PM'	=> { 'Tk' => 402.000, 'Text::English' => 0 },
	'DISTNAME'	=> 'Tk-Pod',
	'NAME'		=> 'Tk',
	'VERSION'	=> 0.07,

	'EXE_FILES'	=> [ 'tkpod' ],

        'dist'		=> {'COMPRESS'=>'gzip -9f', 'SUFFIX'=>'.gz'}, 
);
