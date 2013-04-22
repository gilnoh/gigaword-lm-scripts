use strict;
use warnings; 
use octave_call; 
use srilm_call; 
use proto_condprob qw(:DEFAULT set_num_thread P_coll P_doc plucene_query $COLLECTION_MODEL $DOCUMENT_INDEX_DIR $DEBUG $APPROXIMATE_WITH_TOP_N_HITS); 
use Test::Simple tests => 16; 

# test data 
# (just for the test, not meaningful at all) 
my $testinput = "we can not say yet if there will be an agreement , \" said Merkel on her way into the summit .";  
my $testh = "an agreement may be reached in the summit . "; 

## lambda_sum 
my $l = 0.9; 
my @left = (0.1, 0.2); 
my @right = (0.02, 0.03); 
my $result_oct = lambda_sum($l, \@left, \@right); 
ok($result_oct, "calling lambda sum on OCTAVE: $result_oct"); 

my $result = lambda_sum2($l, \@left, \@right); 
ok(($result - $result_oct) < 0.0001, "calling labmda sum yet another: $result"); 
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
ok( ((($result - (-42.5641)) < 0.001) or ($result - (-42.274) < 0.001 )) , "reading debug3 output of SRILM ngram ouput, and lambda_sum: $result"); # the value from very slow ngram mix-model output (debug3_interpolate.out) 
close FILE_C; 
close FILE_D; 

## call_ngram
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

my %result; 
## P_t that uses P_doc and P_coll 
if (-e $COLLECTION_MODEL)
{
    # P_t() arguments: text, lambda, collection model, document model glob 
    %result = P_t($testinput, 0.5, $COLLECTION_MODEL, "./testdata"); 
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
    ok(1, "ignoring calling P_t, missing collection model in $COLLECTION_MODEL"); 
}

## Run P_t multithread and check the result is the same. 

my %result2; 

if (-e $COLLECTION_MODEL)
{
    # P_t_multithread() arguments: text, lambda, collection model, document model glob 
    my $nthread = 3;
    proto_condprob::set_num_thread($nthread); 
    %result2 = P_t_multithread($testinput, 0.5, $COLLECTION_MODEL, "./testdata"); 
    my $result_same = 1; 
    foreach (keys %result2)
    {
	print "\t$_\t$result2{$_}\n"; 
	$result_same = 0 if ($result{$_} != $result2{$_}); 
    }
    my @a = values %result; 
    print "\t Average logprob from the doc-models (with $nthread threads): ", mean(\@a), "\n"; 
    ok($result_same, "calling P_t_multithread done, result the same"); 
}
else
{
    ok(1, "ignoring calling P_t_multithread, missing collection model in $COLLECTION_MODEL"); 
}

# P_t on another sentence (hypothesis in next test) 
my %result3; 
if (-e $COLLECTION_MODEL)
{
    %result3 = P_t($testh, 0.5, $COLLECTION_MODEL, "./testdata"); 
    foreach (keys %result3)
    {
	print "\t$_\t$result3{$_}\n"; 
    }
    my @a = values %result3; 
    print "\t Average logprob from the doc-models: ", mean(\@a), "\n"; 
    ok(1, "calling P_t on another sentence");     
}
else
{
    ok(1, "ignoring another call to P_t"); 
}


## P_h_t_multithread
our $DEBUG; $DEBUG = 2; # set debug level 2
if (-e $COLLECTION_MODEL)
{
    my $nthread = 3;
    proto_condprob::set_num_thread($nthread); 
    my ($gain,$P_h_t, $P_h, $P_t ,$href) = P_h_t_multithread($testh, $testinput, 0.5, $COLLECTION_MODEL, "./testdata"); 

    print "Non-normalized contribution of documents (evidences)\n"; 
    foreach (keys %$href)
    {
	print "\t $_ \t $href->{$_}\n"; 
    }    
    ok(1, "P_h_t_multithread ran Okay"); 

    # finally, check %result2 + %result3 is this $href 
    my $result_same = 1; 
    my @t; my @h; 
    foreach (keys %$href)
    {
	$result_same = 0 unless ($href->{$_} == ($result2{$_} + $result3{$_})); 
	push @t, $result2{$_}; 
	push @h, $result3{$_}; 
    }
    # and check they end up the same; 
    my $dcheck = weighted_sum(\@t, \@h); 
    $result_same = 0 unless ($dcheck == $P_h_t); 
    ok($result_same, "And P_h_t result concurs to P_t on t and h"); 
}
else
{
   ok(1, "ignoring calling P_h_t_multithread, missing collection model in $COLLECTION_MODEL"); 
   ok(1, "ignoring calling P_h_t_multithread, missing collection model in $COLLECTION_MODEL"); 
}

#plucene query test
our $DOCUMENT_INDEX_DIR = "./testdata/models_index"; 
if (-e $DOCUMENT_INDEX_DIR)
{
    my ($docid_aref, $docscore_href, $total_doc) = plucene_query("football hiddink"); 
    foreach (@{$docid_aref})
    {
	print "$_: ", $docscore_href->{$_}, "\n"; 
    }
    print "among $total_doc documents\n"; 
    # check order: .0481, .0480, .0482, .0484 
    # and 483 not in there. 
    ok((($docid_aref->[0] =~ /0481\.story/) and ($docid_aref->[1] =~ /0480\.story/)), "query result as expected"); 
}
else
{
    ok(1, "ignoreing calling plucene_query, missing index dir $DOCUMENT_INDEX_DIR"); 
}


# P_t_multithread_index test 
my %result4; 
if (-e $COLLECTION_MODEL)
{
    %result4 = P_t_multithread_index($testh, 0.5, $COLLECTION_MODEL, "./testdata", "./testdata/models_index"); 
    foreach (keys %result4)
    {
	print "\t$_\t$result4{$_}\n"; 
    }
    my @a = values %result4; 
    print "\t Average logprob from the doc-models: ", mean(\@a), "\n"; 
    ok(1, "calling P_t_ multithread index ..."); 
}
else
{
    ok(1, "ignoring another call to P_t"); 
}

# approximate by using top n ... 
my %result5; 
if (-e $COLLECTION_MODEL)
{
    our $APPROXIMATE_WITH_TOP_N_HITS = 1; 
    %result5 = P_t_multithread_index($testh, 0.5, $COLLECTION_MODEL, "./testdata", "./testdata/models_index"); 
    foreach (keys %result5)
    {
	print "\t$_\t$result5{$_}\n"; 
    }
    my @a = values %result5; 
    print "\t Average logprob from the doc-models: ", mean(\@a), "\n"; 
    ok(1, "calling P_t_ multithread index with top N approximation."); 
}
else
{
    ok(1, "ignoring another call to P_t"); 
}
