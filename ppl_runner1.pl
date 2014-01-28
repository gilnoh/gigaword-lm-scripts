# this small script runs and calculate 
# ppl of each sentence, by calling 
# condprob_h_given_t; with the target sentence as the target (h) 
# and context (pre or next sentences) as context (t). 

use warnings; 
use strict; 
use Benchmark qw(:all); 
use condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS $NOHIT_L0_FILL export_hash_to_file); 

## configurable values 
## 

# from condprob.pm  
#
our $DEBUG = 0; # no debug output 
our $SOLR_URL = "http://127.0.0.1:9911/solr";
set_num_thread(4);
our $APPROXIMATE_WITH_TOP_N_HITS=5000;

# own configuration values
#
# - method to select context
our $SELECT_CONTEXT = \&prev_one;
# all $SELECT_CONTEXT should accept the following form of args 
# > select_context_method_name(doc_array_ref, sent_num) 
# e.g.  $SELECT_CONTEXT->($arr_ref, 35); 

# - half sentence flag. 
our $HALF_SENTENCE_IN_CONTEXT = 0;
# if 0; just normal P (content sentence | context) 
# if 1; query is done with P( content-late-half-sentence | context-given + first-half-sentence) 
our $BOTH_HALF = 0; # only meaningful when HALF_SENTENCE_IN_CONTEXT is on. 
# if 0; only P( later_half | context) is calculated. 
# if 1; both P( later_half | context) and P (first half | context) is calculated. 

# words only (clears sentences from comma, collon, quotes, etc) 
our $WORDS_ONLY = 0;

# clean heading & trailing (clears sentences start and ending) 
our $CLEAN_HEAD_AND_TRAIL = 0;

# ignore texts with less than N sentences. 
# set 0, if you will run any&every documents. 
our $DOC_MIN_NUM_SENTENCES = 0;

## global (if any)
##
my $instance_id = "ppl1";


## code start
##

unless ($ARGV[0] && $ARGV[1])
{
    die "requires at least two or more arguments\n   - instance_id (unique id of this run. any string, but unique)\n   - one (or more) text file names (the file as same as to be passed for SRILM -ppl).\n example: > perl ppl_runner.pl \"myrun1\" ./testdata/*.story\n"; 
}

# time in 
my $t0 = Benchmark->new; 
$instance_id = shift @ARGV; 
my @files = @ARGV; 

# variables to store all 
my $total_P_coll = 0; 
my $total_P_model = 0;  
my $total_P_model_conditioned = 0; 
my $total_count_nonOOV = 0; 
my $total_count_sent = 0; 

my $number_of_processed_doc = 0; 

foreach my $filename (@files)
{
    die "unable to read file $filename\n" unless (-r $filename); 
    # we got one file; already tokenized and sentence splitted. 
    print $filename, "\n"; 
    my $raw_content; 
    open INFILE, "<", $filename; 
    $raw_content .= $_ while (<INFILE>); 
    close INFILE; 
    my @temp = split /\n/, $raw_content; 
    my @sentences; 
    foreach (@temp) # prepare text 
    {
	#remove all empty lines, so "real lines only"
	next unless (/\S/); # next if whitespce only
	next unless (/\w/); # next if there's no alphanumeric char. 

	if ($WORDS_ONLY) # option, remove punctuals. (" , . etc). note that the underlying model should have also trained in that way! 
	{
	    push @sentences, words_only($_); 
	}
	elsif ($CLEAN_HEAD_AND_TRAIL) # option: clean heading and trailing quotes, and other punctuals. Make clearner input. 
	{
	    push @sentences, clear_head_and_trail($_); 
	}
	else # just as is. 
	{
	    push @sentences, $_; 
	}
    }    

    # calling of the main method. 
    # will return total prob & ppl. 
    
    # skip if num sentence is less than minimum (why? too few sentence makes
    # it harder to extract context parts. (e.g. prev-3, next-3, etc) 
    if ( (scalar @sentences) < $DOC_MIN_NUM_SENTENCES )
    {
	print STDERR "$filename is shorter than $DOC_MIN_NUM_SENTENCES sentences. passing\n"; 
	next; 
    }

    # main PPL calculation method (condprob.pm) 
    my ($sum_P_coll, $sum_P_model, $sum_P_model_conditioned, $sum_count_nonOOV, $sum_count_sent) = ppl_one_doc(@sentences); 

    # sumup 
    $total_P_coll += $sum_P_coll; 
    $total_P_model += $sum_P_model; 
    $total_P_model_conditioned += $sum_P_model_conditioned; 
    $total_count_nonOOV += $sum_count_nonOOV; 
    $total_count_sent += $sum_count_sent; 
    $number_of_processed_doc++; 
}

print "====\n";
print "====\n"; 
print "Number of documents processed: $number_of_processed_doc\n"; 
print "$total_P_coll \t $total_P_model \t $total_P_model_conditioned \t $total_count_nonOOV \t $total_count_sent\n"; 
print "All Collection logprob: $total_P_coll (ppl: ", calc_ppl($total_P_coll, $total_count_nonOOV, $total_count_sent), ")\n";
print "All model logprob: $total_P_model (ppl: ", calc_ppl($total_P_model, $total_count_nonOOV, $total_count_sent), ")\n";
print "All conditioned model logprob: $total_P_model_conditioned (ppl: ", calc_ppl($total_P_model_conditioned, $total_count_nonOOV, $total_count_sent), ")\n";

# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print "the code took:", timestr($td), "\n"; 
exit(); 

# end of top level 

##
## main method 
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

	# test/temporary 
	# if ($CONTENT_INCLUDES_CONTEXT)
	# {
	#     $content = $context . "\n" . $content; 
	# }

	# if ($CONTEXT_INCLUDES_CONTENT)
	# {
	#     $context = $context . "\n" . $content; 
	# }

	if ($HALF_SENTENCE_IN_CONTEXT)
	{
	    my ($first_half, $later_half) = divide_sentence_half($content); 	    
	    $context = $context . "\n" . $first_half; 
	    $content = $later_half; 
	}

	my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document", $instance_id);

	print "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

	# undef check. (non word setnence like "..." can make undef)  
	if (defined $P_model)
	{
	    # sum 
	    $sum_P_coll += $P_coll; 
	    $sum_P_model += $P_model; 
	    $sum_P_model_conditioned += $P_model_conditioned; 
	    $sum_count_nonOOV += $count_nonOOV; 
	    $sum_count_sent += $count_sent; 
	}
	else
	{
	    warn "non-words only, or all OOV sentence, passing the sentence\n"; 
	    print "non-words only, or all OOV sentence, passing the sentence\n" 
	}
	
	# exceptional case for half sentence test 
	if ($HALF_SENTENCE_IN_CONTEXT && $BOTH_HALF)
	{  
	    $content = $sent[$i]; 
	    $context = 	$SELECT_CONTEXT->(\@sent, $i); 

	    my ($first_half, $later_half) = divide_sentence_half($content);  
	    $context = $context . "\n" . $later_half; 
	    $content = $first_half; 

	    my ($P_coll, $P_model, $P_model_conditioned, $count_nonOOV, $count_sent  ) = condprob_h_given_t($content, $context, 0.5, "./models/collection/collection.model", "./models/document", $instance_id);

	    print "$P_coll \t $P_model \t $P_model_conditioned \t $count_nonOOV \t $count_sent\n"; 

	    # undef check again 
	    if (defined $P_model)
	    {
		# sum 
		$sum_P_coll += $P_coll; 
		$sum_P_model += $P_model; 
		$sum_P_model_conditioned += $P_model_conditioned; 
		$sum_count_nonOOV += $count_nonOOV; 
		$sum_count_sent += $count_sent; 
	    }
	    else
	    {

		warn "non-words only, or all OOV sentence, passing the sentence\n"; 
		print "non-words only, or all OOV sentence, passing the sentence\n" 
	    }

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
sub doc_all_is
{
    my $aref = shift;
    my $sent_index = shift;
    # always return the whole document.
    my $result = ""; 
    for (my $i=0; $i < scalar (@$aref); $i++)
    {
        $result .= ( $aref->[$i] . "\n"); 
    }
    return $result; 
}

sub prev_all
{
    my $aref = shift; 
    my $sent_index = shift; 
    if ($sent_index == 0) {
    	return ""; 
	#return $aref->[0]; # or next one? 
    }
    else 
      {
        my $result = "";
        for (my $i=0; $i < $sent_index; $i++)
          {
            $result .= ( $aref->[$i] . "\n");
          }
	return $result; 
      }
}
sub prev_one
{ 
    my $aref = shift; 
    my $sent_index = shift; 
    if ($sent_index == 0) {
    	return ""; 
	#return $aref->[0]; # or next one? 
    }
    else 
    {
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

sub one_sent_window_is
{
  # prev and next one sentence. + self.
    my $aref = shift;
    my $sent_index = shift;
    my $prev_part;
    my $next_part;

    my $point = $sent_index;

    # prev part
    $point--;
    if ($point >= 0)
    {
      $prev_part .= $aref->[$point] ."\n";
    }

    #next part
    $point=$sent_index;
    $point++; 
    if ($point < scalar(@$aref))
    {
      $next_part .= $aref->[$point] ."\n";
    }


    #self part
    my $self = $aref->[$sent_index]; 
    return $prev_part . $next_part . $self;
}

sub two_sent_window_is
{
  # prev and next one sentence. + self.
    my $aref = shift;
    my $sent_index = shift;
    my $prev_part = "";
    my $next_part = "";

    my $point = $sent_index;

    # prev part
    $point--;
    if ($point >= 0)
    {
      $prev_part .= $aref->[$point] ."\n";
    }
    $point--;
    if ($point >= 0)
    {
      $prev_part .= $aref->[$point] ."\n";
    }


    #next part
    $point=$sent_index;
    $point++; 
    if ($point < scalar(@$aref))
    {
      $next_part .= $aref->[$point] ."\n";
    }
    $point++; 
    if ($point < scalar(@$aref))
    {
      $next_part .= $aref->[$point] ."\n";
    }

    #self part
    my $self = $aref->[$sent_index]; 
    return $prev_part . $next_part . $self;
  }

sub three_sent_window_is
{
  # prev and next one sentence. + self.
    my $aref = shift;
    my $sent_index = shift;
    my $prev_part = "";
    my $next_part = "";

    my $point = $sent_index;

    # prev part
    $point--;
    if ($point >= 0)
    {
      $prev_part .= $aref->[$point] ."\n";
    }
    $point--;
    if ($point >= 0)
    {
      $prev_part .= $aref->[$point] ."\n";
    }
    $point--;
    if ($point >= 0)
    {
      $prev_part .= $aref->[$point] ."\n";
    }


    #next part
    $point=$sent_index;
    $point++; 
    if ($point < scalar(@$aref))
    {
      $next_part .= $aref->[$point] ."\n";
    }
    $point++; 
    if ($point < scalar(@$aref))
    {
      $next_part .= $aref->[$point] ."\n";
    }
    $point++; 
    if ($point < scalar(@$aref))
    {
      $next_part .= $aref->[$point] ."\n";
    }

    #self part
    my $self = $aref->[$sent_index]; 
    return $prev_part . $next_part . $self;
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
    $line =~ s/ [:;,."'`] / /g; 
    return $line; 
}

sub clear_head_and_trail
{
   # removes trailing/heading new lines, 
   # and also heading & trailing PUNC tokens. 
   # note that this does not touch (unlike words_only) 
   # any of the in-sentence PUNC classes. 

    my $line = shift; 
    $line =~ s/^\s?[:;,."'`]//g; # clearing head
    $line =~ s/[:;,."'`]\s?$//g; # clearing trail 
    return $line; 
}



# - include context in the content of condprob query 
#our $CONTENT_INCLUDES_CONTEXT = 0; 
# if 0; query is done with P( content (exclude context) | context) 
# if 1; calc is done with P( content in context | context ) 

# - context of the condprob query includes the content
#our $CONTEXT_INCLUDES_CONTENT = 0; 
# if 0; query is done with P( content | context (exclude content)) 
# if 1; query is done with P( content | context + content ) 


