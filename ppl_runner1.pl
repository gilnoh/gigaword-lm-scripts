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
our $SELECT_CONTEXT = \&prev_one; 
# all $SELECT_CONTEXT should accept the following form of args 
# > select_context_method_name(doc_array_ref, sent_num) 
# e.g.  $SELECT_CONTEXT->($arr_ref, 35); 
# 

# - include context in the content of condprob query 
our $CONTENT_INCLUDES_CONTEXT = 0; 
# if 0; query is done with P( content (exclude context) | context) 
# if 1; calc is done with P( content in context | context ) 

# - context of the condprob query includes the content
our $CONTEXT_INCLUDES_CONTENT = 0; 
# if 0; query is done with P( content | context (exclude content)) 
# if 1; query is done with P( content | context + content ) 

# - half sentence test. 
our $HALF_SENTENCE_IN_CONTEXT = 0; 
# if 0; just normal P (content sentence | context) 
# if 1; query is done with P( content-late-half-sentence | context-given + first-half-sentence) 
our $DOUBLE_HALF = 0; # only meaningful when HALF_SENTENCE_IN_CONTEXT is on. 
# if 0; only P( later_half | context) is calculated. 
# if 1; both P( later_half | context) and P (first half | context) is calculated. 


# - documents less that this would be ignored. (not part of ppl run) 
# TODO 
#our $DOC_MIN_NUM_SENTENCES = 5; 

## global (if any) 
##

## code start 
##


# maybe loop over file here? 
my $filename; 
if ($ARGV[0])
{
    $filename = $ARGV[0];
}
else 
{
    die "requires one (or more) file names as arguments\n"; 
    # my $filename = "./testdata/AFP_ENG_20090531.0480.story"; 
}

die "unable to read file $filename\n" unless (-r $filename); 

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
	next unless (/\S/); 
	push @sentences, words_only($_); 
	#push @sentences, $_; 
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

	# context/content tuning for optimal ppl 
	# (another reason that shows ppl value itself doesn't mean much?) 
	if ($CONTENT_INCLUDES_CONTEXT)
	{
	    $content = $context . "\n" . $content; 
	}

	if ($CONTEXT_INCLUDES_CONTENT)
	{
	    $context = $context . "\n" . $content; 
	}

	if ($HALF_SENTENCE_IN_CONTEXT)
	{
	    my ($first_half, $later_half) = divide_sentence_half($content); 	    
	    $context = $context . "\n" . $first_half; 
	    $content = $later_half; 
	}

	my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document");

	print "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

	# sum 
	$sum_P_coll += $P_coll; 
	$sum_P_model += $P_model; 
	$sum_P_model_conditioned += $P_model_conditioned; 
	$sum_count_nonOOV += $count_nonOOV; 
	$sum_count_sent += $count_sent; 

	# exceptional case for half sentence test 
	if ($HALF_SENTENCE_IN_CONTEXT && $DOUBLE_HALF)
	{  
	    $content = $sent[$i]; 
	    $context = 	$SELECT_CONTEXT->(\@sent, $i); 

	    my ($first_half, $later_half) = divide_sentence_half($content);  
	    $context = $context . "\n" . $later_half; 
	    $content = $first_half; 

	    my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document");

	    print "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

	    # sum 
	    $sum_P_coll += $P_coll; 
	    $sum_P_model += $P_model; 
	    $sum_P_model_conditioned += $P_model_conditioned; 
	    $sum_count_nonOOV += $count_nonOOV; 
	    $sum_count_sent += $count_sent; 
	}

    } # for $i < $count 
    # output for this file 
    print "Sum of this doc:\n"; 
    print "$sum_P_coll \t $sum_P_model \t $sum_P_model_conditioned \t $sum_count_nonOOV \t $sum_count_sent\n"; 
    print "Total Collection logprob: $sum_P_coll (ppl: ", calc_ppl($sum_P_coll, $sum_count_nonOOV, $sum_count_sent), ")\n";
    print "Total model logprob: $sum_P_model (ppl: ", calc_ppl($sum_P_model, $sum_count_nonOOV, $sum_count_sent), ")\n";
    print "Finally, conditioned model logprob: $sum_P_model_conditioned (ppl: ", calc_ppl($sum_P_model_conditioned, $sum_count_nonOOV, $sum_count_sent), ")\n";

    return ($sum_P_coll, $sum_P_model, $sum_P_model_conditioned, $sum_count_nonOOV, $sum_count_sent); 
}

##
## utility 
## divide (already tokenized) sentence into two parts, first-half and later-half. 
sub divide_sentence_half
{
    my $input = shift;
    $input =~ s/\s+$//;  # remove trailing newlines 
    my @words = split /\s+?/, $input; 
    my $size = scalar (@words); 
    my $midpoint = $size / 2.0; 
    my $left = join " ", @words[0..($midpoint-1)]; 
    my $right = join " ", @words[$midpoint..($size -1)]; 
    return ($left, $right); 
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
sub none
{
    # only meaningful if you are using 
    # $HALF_SENTENCE_IN_CONTEXT

    return " "; 
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
	

##
## common utility 
sub words_only 
{
    # removes trailing/heading new lines, 
    # and removes any "PUNC as tokens" 
    # (quotes, periods, commas, collons and semicolons. 
    # removed and no longer tokens. ) 

    my $line = shift; 
    $line =~ s/ [:;,."'`] //g; 
    return $line; 
}



