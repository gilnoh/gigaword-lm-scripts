use strict;
use warnings; 
use octave_call; 
use srilm_call;
use Test::Simple tests => 3; 

# lambda_sum 
my $l = 0.9; 
my @left = (0.1, 0.2); 
my @right = (0.02, 0.03); 
my $result = lambda_sum($l, \@left, \@right); 
ok($result == -1.7738); 

# read_debug3_p 
open FILE_C, "<", "./testdata/debug3_coll.out"; 
open FILE_D, "<", "./testdata/debug3_doc.out"; 

my @c = <FILE_C>; 
my @d = <FILE_D>; 
my @c_prob_seq = read_debug3_p(@c); 
my @d_prob_seq = read_debug3_p(@d); 
my $lambda = 0.5; 
$result = lambda_sum($lambda, \@d_prob_seq, \@c_prob_seq); 
#print ($result); 
ok(($result - (-42.5641)) < 0.001); # the value from very slow ngram mix-model output (debug3_interpolate.out) 
close FILE_C; 
close FILE_D; 

# call_ngram
my @ngram_result = call_ngram("./testdata/AFP_ENG_20090531.0484.story.model", "we can not say yet if there will be an agreement , \" said Merkel on her way into the summit .");  
my @prob_seq = read_debug3_p(@ngram_result); 

# check the result is Okay. 
my $all_identical = 1; 
for(my $i=0; $i < scalar(@prob_seq); $i++)
{
    $all_identical = 0 if ($prob_seq[$i] != $d_prob_seq[$i]);  
}
ok($all_identical); 
print @prob_seq, "\n"; 
print @d_prob_seq, "\n"; 
