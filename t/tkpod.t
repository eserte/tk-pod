BEGIN { $^W = 1; };
use Tk;
print "1..1\n";
@ARGV = 'tkpod';
print "ok 1\n";
do 'blib/script/tkpod' unless $ENV{BATCH};

