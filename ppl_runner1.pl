# this small script runs and calculate 
# ppl of each sentence, by calling 
# condprob_h_given_t; with the target sentence as the target (h) 
# and context (pre or next sentences) as context (t). 

use warnings; 
use strict; 
use Benchmark qw(:all); 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 

## configurable values 
## 

our $SELECT_CONTEXT = \&prev_one; #\&all_else;  # prev_one, etc. 
# all $SELECT_CONTEXT should accept the following form of args 
# > select_context_method_name(doc_array_ref, sent_num) 
# $SELECT_CONTEXT->($arr_ref, 35); 

## global (if any) 

## code start 

# maybe loop over file here? 

my $filename = "./testdata/AFP_ENG_20090531.0480.story"; 

# we got one file; already tokenized and sentence splitted. 
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
    ppl_one_doc(@sentences) 
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
	print STDERR "$i: $sent[$i]: \t\t context: $context\n"; 

	# TODO 
	# calling condprob_h_given_t 
	

    }
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

sub all_else 
{
    # to write 
    return ""; 
}

sub three_sent_window
{
    # to write 
    return ""; 
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
	




