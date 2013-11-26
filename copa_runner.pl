# small script that reads and run copa data 
use warnings; 
use strict; 
use Benchmark qw(:all); 
use condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file); 

## configurable values 
## 

# from condprob.pm  
#
our $DEBUG = 0; # no debug output 
set_num_thread(4); 
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

# config from  this runner
# 
my $filename = "./testdata/copa-dev.xml";


# start of the code 
# 

die unless (-r $filename); 

open FILEIN, "<", $filename; 

my $num_processed = 0; 
while (<FILEIN>)
{
    # for each id
    my $line = $_; 
    if ($line =~ /<item id=\"(.?+)\"/)
    {
	my $id = $1; 
	# if cause (what causes this) arrange P(p | a1), P(p | a2) 
	# WARNING - we simply assume that item has no blanks. 
	# and ordered P, a1, and a2. not very tight checking. 
	my $p = <FILEIN>; 
	my $a1 = <FILEIN>; 
	my $a2 = <FILEIN>; 
	
	$p=~s/^\s+<p>//; $p=~s/<\/p>\s?$//; 
	$a1=~s/^\s+<a1>//; $a1=~s/<\/a1>\s?$//; 
	$a2=~s/^\s+<a2>//; $a2=~s/<\/a2>\s?$//; 

	my $first_question_text; 
	my $first_question_context; 
	my $second_question_text; 
	my $second_question_context; 
	   
	# check cause or effect 
	if ($line =~ /asks-for="cause"/)
	{
	    print "$id: \"$p\" -- what caused this\n"; 
	    print "\t a1: $a1\n"; 
	    print "\t a2: $a2\n"; 
	    print STDERR "The runner will compare P ( \"$p\" | \"$a1\" ) and P( \"$p\" | \"$a2\" )\n"; 
	    my ($cp, $cppl, $mp, $mppl, $condp, $condppl) = call_condprob($p, $a1); 
	    print "a1: $cppl, $mppl, $condppl\t ppl-gain: ", $mppl - $condppl, "\n"; 
	    ($cp, $cppl, $mp, $mppl, $condp, $condppl) = call_condprob($p, $a2); 
	    print "a2: $cppl, $mppl, $condppl\t ppl-gain: ", $mppl - $condppl, "\n"; 
	}
	elsif ($line =~ /asks-for="effect"/)
	{
	    # if effect, arrange P(a1 | p), P(a2 | p)
	    print "$id: \"$p\" -- what would be the effect of this\n"; 
	    print "\t a1: $a1\n"; 
	    print "\t a2: $a2\n"; 
	    print STDERR "The runner will compare P( \"$a1\" | \"$p\" ) and P( \"$a2\" | \"$p\" )\n"; 
	    my ($cp, $cppl, $mp, $mppl, $condp, $condppl) = call_condprob($a1, $p); 
	    print "a1: $cppl, $mppl, $condppl\t ppl-gain: ", $mppl - $condppl, "\n"; 
	    ($cp, $cppl, $mp, $mppl, $condp, $condppl) = call_condprob($a2, $p); 
	    print "a2: $cppl, $mppl, $condppl\t ppl-gain: ", $mppl - $condppl, "\n"; 
	}
	else
	{
	    die "eh, an item should have cuase or effect. But it hans't: $line\n"; 
	}
    
	$num_processed++; 
	last if ($num_processed > 10);  # dcode 
    } # end if item 
}

# worker method that calls and gets result of condprob 
# and reports the result to STDOUT 

# usage call_condprob ($content_sentence(s), $context_sentences(s))
# the call will return results of condprob_h_given_t()
# as prob, ppl, prob, ppl, prob, ppl 
sub call_condprob 
{
    my $content = shift; 
    my $context = shift; 
    my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document");
    print STDERR "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

    my $PPL_coll = calc_ppl($P_coll, $count_nonOOV, $count_sent); 
    my $PPL_model = calc_ppl($P_model, $count_nonOOV, $count_sent); 
    my $PPL_model_conditioned = calc_ppl($P_model_conditioned, $count_nonOOV, $count_sent); 

    return ($P_coll, $PPL_coll, $P_model, $PPL_model, $P_model_conditioned, $PPL_model_conditioned); 
}



	# my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document");

	# print "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

