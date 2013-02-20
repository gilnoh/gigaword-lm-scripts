use strict;
use warnings; 
use octave_call; 
use srilm_call; 
use proto_condprob qw(P_coll P_doc P_t $COLLECTION_MODEL); 
use Test::Simple tests => 9; 

## lambda_sum 
my $l = 0.9; 
my @left = (0.1, 0.2); 
my @right = (0.02, 0.03); 
my $result = lambda_sum($l, \@left, \@right); 
ok(($result - -1.7738) < 0.0001, "calling lambda sum on OCTAVE"); 

$result = lambda_sum2(1, \@left, \@right); 
ok(($result - -1.6990) < 0.0001, "calling labmda sum yet another"); 
## read_debug3_p 
open FILE_C, "<", "./testdata/debug3_coll.out"; 
open FILE_D, "<", "./testdata/debug3_doc.out"; 

my @c = <FILE_C>; 
my @d = <FILE_D>; 
my @c_prob_seq = read_debug3_p(@c); 
my @d_prob_seq = read_debug3_p(@d); 
my $lambda = 0.5; 
$result = lambda_sum($lambda, \@d_prob_seq, \@c_prob_seq); 
#print ($result); 
ok(($result - (-42.5641)) < 0.001, "reading debug3 output of SRILM ngram ouput"); # the value from very slow ngram mix-model output (debug3_interpolate.out) 
close FILE_C; 
close FILE_D; 

## call_ngram
my $testinput = "we can not say yet if there will be an agreement , \" said Merkel on her way into the summit .";  
my @ngram_result = call_ngram("./testdata/AFP_ENG_20090531.0484.story.model", "", $testinput);  
my @prob_seq = read_debug3_p(@ngram_result); 

# check the result is Okay. 
my $all_identical = 1; 
for(my $i=0; $i < scalar(@prob_seq); $i++)
{
    $all_identical = 0 if ($prob_seq[$i] != $d_prob_seq[$i]);  
}
ok($all_identical, "calling+accessing SRILM ngram"); 
#print @prob_seq, "\n"; 
#print @d_prob_seq, "\n"; 

## weighted_sum call (LOG probabilities) 
my @a = (-1.00000, -0.69897, -0.52288, -0.39794); 
my @b = (-1.69897, -2.0, -2.0, -2.0);     

my $r = weighted_sum(\@a, \@b); 
ok($r == -1.9586, "calling weighted_sum on OCTAVE"); 
#ok(1, "calling weighted sum on OCTAVE"); 

## mean 
my @mean_data = (-0.4973960, -0.0517816, -0.6938937, -1.2344063, -0.1251993, -0.4130810, -0.7731068, -0.0899830, -0.0089617, -0.0286763); 
$r = mean(\@mean_data); 
ok (($r - (-0.25969)) < 0.0001, "mean of log probs on OCTAVE"); 

## P_coll 
our $COLLECTION_MODEL; #from proto_condprob 
if (-e $COLLECTION_MODEL) 
{
    my @collection_seq = P_coll($testinput); 
    my $logprob = lambda_sum(1, \@collection_seq, \@collection_seq); 
    ok (scalar(@collection_seq), "P_coll, call okay, final logp was $logprob"); 
    #print @collection_seq, "\n"; 
}
else
{
    ok (1, "ignoring P_coll test, missing collection model"); 
}

## P_doc 
if (-e $COLLECTION_MODEL)
{
    my $logprob = P_doc("./testdata/AFP_ENG_20090531.0484.story.model"); 
    ok($logprob, "interpolation done with a test data and collection data, $logprob"); 
}
else 
{
    ok(1, "ignoring calling P_doc, missing collection model"); 
}

## Finally, P_t that uses P_doc and P_coll 

if (-e $COLLECTION_MODEL)
{
    # P_t() arguments: text, lambda, collection model, document model glob 
    my %result = P_t($testinput, 0.5, $COLLECTION_MODEL, "./testdata/*.story.model"); 
    foreach (keys %result)
    {
	print "\t$_\t$result{$_}\n"; 
    }
    my @a = values %result; 
    print "\t Average logprob from the doc-models: ", mean(\@a), "\n"; 
    ok(1, "calling P_t done"); 
}
else 
{
    ok(1, "ignoring calling P_t, missing collection model in /output"); 
}
