# temporary sketch of the experiment, 

use warnings; 
use strict; 
#use proto_condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file plucene_query solr_query P_t_index P_h_t_index $SOLR_URL); 
use condprob qw(:DEFAULT set_num_thread $DEBUG $APPROXIMATE_WITH_TOP_N_HITS export_hash_to_file P_t_index $SOLR_URL get_document_count wordPMI mean_allword_pmi product_best_word_condprob idf_word mean_best_wordPMI log10 KL_divergence); 
use octave_call; 
use Benchmark qw(:all); 

our $DEBUG = 0; # no debug output 
our $SOLR_URL = "http://127.0.0.1:9911/solr";
set_num_thread(4);
our $APPROXIMATE_WITH_TOP_N_HITS=4000;

# word PMI usage 
# print "gold: ", get_document_count("horse"), "\n"; 
# print "silver: ", get_document_count("computer"), "\n"; 
# print "gold & silver: ", get_document_count("horse", "computer"),"\n"; 
#print "pmi(horse, computer): ", wordPMI("horse", "computer"), "\n"; 
#print "pmi(gold, silver): ", wordPMI("gold", "silver"), "\n"; 
#exit(); 

#my $text = lc "we all feel the same";
#my $hypothesis = lc "we all feel the same \n we feel very close to him";

my $text = lc "A bus collision with a truck in Uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
my $hypothesis = lc "30 dies in a bus collision in Uganda"; 

if ($ARGV[0] and $ARGV[1])
{
    $text = call_splitta($ARGV[0]); 
    $hypothesis = call_splitta($ARGV[1]); 
}

# baselines ... 
# mean PMI 
#my $mean_pmi = mean_allword_pmi($text, $hypothesis); 
#print "Mean PMI: $mean_pmi\n"; 
# product condprob-per-word
#my $word_logprob = product_best_word_condprob($text, $hypothesis); 
#print "Best word-condprob: $word_logprob\n"; 
# weighted_mean_best_wordPMI 
#my ($mean, $weighted_mean) = mean_best_wordPMI($text, $hypothesis); 
#print "mean best wordPMI: mean: $mean, IDF-weighted mean: $weighted_mean\n"; 

# print "idf of gold: ", idf_word("gold"), "\n"; 
# print "idf of have: ", idf_word("have"), "\n"; 
# print "idf of own: ", idf_word("own"), "\n"; 
# print "idf of microsoft: ", idf_word("microsoft"), "\n"; 
# die;

# time in 
my $t0 = Benchmark->new; 
# arguments: (context, text, lamda, collection model file, document models top path, instance_id)
# return values: (P_collection(h), P_model(h), P_model(h|t), count_nonOOV_words, count_sentence, P_collection(t), P_model(t), count_nonOOV_words_t, count_sentence_t) 

my ($P_h_coll, $P_h, $P_h_given_t, $count_word_h, $count_sent_h, $P_t_coll, $P_t, $count_word_t, $count_sent_t, $KLD_h_t, $KLD_t_h ) = condprob_h_given_t($hypothesis, $text, 0.5, "./models/collection/collection.model", "./models/document", "sketch");

my $t_ppl = calc_ppl($P_t, $count_word_t, $count_sent_t); 
my $h_ppl = calc_ppl($P_h, $count_word_h, $count_sent_h); 
my $h_given_t_ppl = calc_ppl($P_h_given_t, $count_word_h, $count_sent_h); 

print "returned values\n"; 
print "P(h) (coll, model): $P_h_coll, $P_h\n"; 
print "P(t) (coll, model): $P_t_coll, $P_t\n"; 
print "P(h|t) (model): $P_h_given_t\n"; 
print "PPL(t): $t_ppl\n"; 
print "PPL(h): $h_ppl\n"; 
print "PPL(h|t): $h_given_t_ppl\n"; 
print "PMI(h,t): ", ($P_h_given_t - $P_h), "\n"; 
print "PMI(h,t) / h_len: ", ($P_h_given_t - $P_h) / ($count_word_h + $count_sent_h), "\n"; 
print "PMI(h,t) / t_len + h_len: ", ($P_h_given_t - $P_h) / ($count_word_h + $count_sent_h + $count_word_t + $count_sent_t), "\n"; 
print "PPL gain (%): ", ($h_ppl -  $h_given_t_ppl) / $h_ppl, "\n"; 
print "KLD(H||T): $KLD_h_t\n"; 
print "KLD(T||H): $KLD_t_h\n"; 

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



# KLD
# my @d1; 
# my @d2; 
# push @d1, (log10(0.3)); 
# push @d1, (log10(0.4)); 
# push @d1, (log10(0.1)); 
# push @d1, (log10(0.2)); 

# push @d2, (log10(0.4)); 
# push @d2, (log10(0.3)); 
# push @d2, (log10(0.1)); 
# push @d2, (log10(0.2)); 

# my $val = KL_divergence(\@d2, \@d1); 
# print "KLD = $val\n"; 
# die; 
