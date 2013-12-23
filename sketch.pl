# temporary sketch of the experiment, 

use warnings; 
use strict; 
#use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file plucene_query solr_query P_t_index P_h_t_index $SOLR_URL); 
use condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file P_t_index $SOLR_URL); 
use octave_call; 
use Benchmark qw(:all); 

our $DEBUG = 0; # no debug output 
our $SOLR_URL = "http://127.0.0.1:9911/solr";
set_num_thread(4);
our $APPROXIMATE_WITH_TOP_N_HITS=4000;

my $text = lc "we all feel the same";
my $hypothesis = lc "we all feel the same \n we feel very close to him";

#my $text = lc "A bus collision with a truck in Uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
#my $hypothesis = lc "30 dies in a bus collision in Uganda"; 

if ($ARGV[0] and $ARGV[1])
{
    $text = call_splitta($ARGV[0]); 
    $hypothesis = call_splitta($ARGV[1]); 
}

# time in 
my $t0 = Benchmark->new; 
# arguments: (context, text, lamda, collection model file, document models top path, instance_id)
condprob_h_given_t($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document", "sketch");

# time out
my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print "the code took:", timestr($td), "\n"; 
exit(); 

# # 2nd run, real, normal expected time for pairs. 
# P_h_t_index($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document");

# my $t2 = Benchmark->new; 
# $td = timediff($t2, $t1); 
# print "2nd time (the normal time) it took: ", timestr($td), "\n"; 


