BEGIN { $^W = 1; };
print "1..1\n";
@ARGV = 'tkpod';
do 'blib/script/tkpod';
print "ok 1\n";
