# this small script runs and calculate 
# ppl of each sentence, by calling 
# condprob_h_given_t; with the target sentence as the target (h) 
# and context (pre or next sentences) as context (t). 

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

# own configuration values
#
# - method to select context 
our $SELECT_CONTEXT = \&prev_three; 
# all $SELECT_CONTEXT should accept the following form of args 
# > select_context_method_name(doc_array_ref, sent_num) 
# e.g.  $SELECT_CONTEXT->($arr_ref, 35); 
# 

# - include context in the content of condprob query 
# (this is a bit weird. e.g. different counts of  sentence/words per context
# choices. commented out for now.)  
#our $CONTENT_INCLUDES_CONTEXT = 0; 
# if 0; query is done with P( content (exclude context) | context) 
# if 1; calc is done with P( content in context | context ) 

# - context of the condprob query includes the content
# (to optimize the ppl value) 
# TODO 
#our $CONTEXT_INCLUDES_CONTENT = 0; 
# if 0; query is done with P( content | context (exclude content)) 
# if 1; query is done with P( content | context + content ) 

# - documents less that this would be ignored. (not part of ppl run) 
# TODO 
#our $DOC_MIN_NUM_SENTENCES = 5; 

## global (if any) 
##

## code start 
##

# maybe loop over file here? 

my $filename = "./testdata/AFP_ENG_20090531.0480.story"; 

# we got one file; already tokenized and sentence splitted. 
# todo, loop over file 
{
    my $raw_content; 
    open INFILE, "<", $filename; 
    $raw_content .= $_ while (<INFILE>); 
    close INFILE; 
    my @temp = split /\n/, $raw_content; 
    my @sentences; 
    foreach (@temp) #remove all empty lines, so "real lines only"
    {
	push @sentences, $_ if (/\S/); 
    }

    # calling of the main method. 
    # will return total prob & ppl. 
    
    # TODO: skip if num sentence is less than min 
    # $DOC_MIN_NUM_SENTENCES 
    ppl_one_doc(@sentences); 
}

##
## main work method 
##

# get one story file as an array, where each element holds
# one sentence. (already sentence splitted and tokenized.) 
# check PPL for each sentence, output them. 
# return an array of array. 

sub ppl_one_doc
{
    my @sent = @_; 
    my $count = scalar (@sent); 

    my $sum_P_coll; 
    my $sum_P_model; 
    my $sum_P_model_conditioned; 
    my $sum_count_nonOOV; 
    my $sum_count_sent; 

    # ok. we will calculate conditional probability for each sentence! 
    for(my $i=0; $i < $count; $i++)
    {
	my $context = $SELECT_CONTEXT->(\@sent, $i); 
	
	if (not $context)
	{
	    print STDERR "context of sent $i is null: passing\n"; 
	    next; 
	}
	#dcode 
	#print STDERR "$i: $sent[$i]: \t\t context: $context\n"; 
	
	my $content = $sent[$i]; 
	# if ($CONTENT_INCLUDES_CONTEXT)
	# {
	#     $content = $context . "\n" . $content; 
	# }
	my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document");

	print "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

	# sum 
	$sum_P_coll += $P_coll; 
	$sum_P_model += $P_model; 
	$sum_P_model_conditioned += $P_model_conditioned; 
	$sum_count_nonOOV += $count_nonOOV; 
	$sum_count_sent += $count_sent; 
    }
    # output for this file 
    print "Sum of this doc:\n"; 
    print "$sum_P_coll \t $sum_P_model \t $sum_P_model_conditioned \t $sum_count_nonOOV \t $sum_count_sent\n"; 
    print "Total Collection logprob: $sum_P_coll (ppl: ", calc_ppl($sum_P_coll, $sum_count_nonOOV, $sum_count_sent), ")\n";
    print "Total model logprob: $sum_P_model (ppl: ", calc_ppl($sum_P_model, $sum_count_nonOOV, $sum_count_sent), ")\n";
    print "Finally, conditioned model logprob: $sum_P_model_conditioned (ppl: ", calc_ppl($sum_P_model_conditioned, $sum_count_nonOOV, $sum_count_sent), ")\n";

    return ($sum_P_coll, $sum_P_model, $sum_P_model_conditioned, $sum_count_nonOOV, $sum_count_sent); 
}

##
## context extraction methods 
## argument: array_reference, sentence num (0 - n) 
sub prev_one
{ 
    my $aref = shift; 
    my $sent_index = shift; 
    if ($sent_index == 0) {
	return ""; 
    }
    else {
	return $aref->[$sent_index - 1]; 
    }
}
sub prev_two
{
    my $aref = shift; 
    my $sent_index = shift; 
    if ($sent_index < 2) {
	return ""; 
    }
    else {
	my $context = "";
	$context .= $aref->[$sent_index - 2] . "\n"; 
	$context .= $aref->[$sent_index - 1] . "\n"; 
	return $context; 
    }
}

sub prev_three
{
    my $aref = shift; 
    my $sent_index = shift; 
    if ($sent_index < 3) {
	return ""; 
    }
    else {
	my $context = "";
	$context .= $aref->[$sent_index - 3] . "\n"; 
	$context .= $aref->[$sent_index - 2] . "\n"; 
	$context .= $aref->[$sent_index - 1] . "\n"; 
	return $context; 
    }
}

sub first_one 
{
    # return first sentence, regardless. 
    my $aref = shift; 
    return $aref->[0]; 
}

sub first_three
{
    # return first three sentences, regardless 
    my $aref = shift; 
    my $string; 
    $string .= $aref->[0]; 
    $string .= "\n"; 
    $string .= $aref->[1]; 
    $string .= "\n"; 
    $string .= $aref->[2]; 
    return $string; 
}

sub self 
{
    # oh, this is rather interesting case. 
    # looks like an abuse (e.g P(t|t), but it actually is not.) 
    # (e.g. the collection generated this sentence, what is the 
    # probability of generating it again. 
    # as, P( sampling_n ="this sentence" | sampling_n-1 = "that sentence") 
    # 
    # this, set-up *does* seems to reduce a lot of absolute PPL. 
    # But still; self, isn't part of "context". 
    # 
    # Maybe, P( prev+self | prev)  would be the best combination? hmm. 
    # would be interesting. 

}

sub all_else 
{
    # to write 
    return ""; 
}

sub whole_document 
{
    # hmm? equal to all_else. doesn't it? 
    # to write (ehh-heee) 
    return ""; 
}

sub three_sent_window
{
    # prev 3 + next 3 
    # to write 
    return ""; 
}

sub n_most_rare
{
    # oh. possible but need some work, I guess. 
    # 1) run for each sentence, P_coll 
    # 2) get three most suprising sentences... 
    # 3) return them as context? 
}


# my $filename = $ARGV[0]; 

# # maybe loop (for files) here? or sub here? 

# cur_given_prev($filename); 
# exit(); 



# sub cur_given_prev 
# {
#     my $filename = $_[0]; 
#     die "eh, unable to read the file $filename \n" unless (-r $filename); 

#     open FILE, "<", "$filename"; 
	
#     my $prev_sent = "";  
#     while(<FILE>)
#     {
# 	next unless ($_ =~ /\S+/); 
# 	my $cur_sent = $_; 
# 	unless ($prev_sent) # $cur_sent is the first sentence 
# 	{
# 	    $prev_sent = $cur_sent; 
# 	    next; 
# 	}
# 	P_h_t_index($cur_sent, $prev_sent, 0.5, "./models/collection/collection.model", "./models/document"); 
# 	$prev_sent = $cur_sent; 
#     }

#     close FILE; 
# }
	




