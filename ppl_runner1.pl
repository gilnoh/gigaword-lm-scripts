# this small script runs and calculate 
# ppl of each sentence, by calling 
# condprob_h_given_t; with the target sentence as the target (h) 
# and context (pre or next sentences) as context (t). 

use warnings; 
use strict; 
use Benchmark qw(:all); 
use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file $SOLR_URL); 


our $SELECT_CONTEXT = prev_sent;  # method name. 
# select_context_method_name(doc_array_ref, sent_num) 

# get one story file as an array, where each element holds
# one sentence. (already sentence splitted and tokenized.) 
# check PPL for each sentence, output them. 
# return an array of array. 

sub ppl_one_document 
{
    


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
	




