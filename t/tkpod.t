BEGIN { $^W = 0; }; # cease "Too late to run INIT block" warning
use Tk;
print "1..1\n";
@ARGV = 'tkpod';
print "ok 1\n";
$ENV{TKPODDEBUG} = 0;
do 'blib/script/tkpod' unless $ENV{BATCH};

