# small script that tests baseline methods
# (word based PMI and conditional probability) 

use strict; 
use warnings; 
use condprob qw(:DEFAULT get_document_count wordPMI word_condprob $total_doc_count log10); 

use Test::Simple tests => 14; 

# test for get_document_count 
{
    my $gold_count = get_document_count("gold"); 
    my $silver_count = get_document_count("silver"); 
    my $gold_and_silver_count = get_document_count("gold", "silver"); 
    my $very_common = get_document_count("report"); 
    ok(($gold_count > $silver_count), "get_document_count 1"); 
    print "$gold_count > $silver_count\n"; 
    ok(($silver_count > $gold_and_silver_count), "get_document_count 2"); 
    print "$silver_count > $gold_and_silver_count\n"; 
    ok(($very_common > 10000), "get_document_count 3"); 
    print "$very_common > 10000\n"; 
}

# test for wordPMI 
{
    my $PMI_gold_silver = wordPMI("gold", "silver"); 
    ok ($PMI_gold_silver > 0.5, "$PMI_gold_silver > 0.5"); 
    my $PMI_silver_gold = wordPMI("silver", "gold");
    ok ($PMI_gold_silver == $PMI_silver_gold, "$PMI_gold_silver == $PMI_silver_gold"); 
    my $almost_independent = wordPMI("computer", "horse");
    ok ($almost_independent < 0.3, "$almost_independent < 0.3"); 
    my $negative = wordPMI("google", "horse"); 
    ok ($negative < 0, "$negative < 0"); 
    my $OOV_as_zero = wordPMI("TAEGILNOH", "dog"); 
    ok ($OOV_as_zero == 0, "$OOV_as_zero == 0"); 
}

# test for word_condprob
{
    our $total_doc_count; 
    ok ($total_doc_count != 0, "total doc count (from SOLR): $total_doc_count"); 
    my $prob_silver = get_document_count("silver") / $total_doc_count; 
    my $prob_silver_given_gold = word_condprob("silver", "gold"); 
    ok ($prob_silver_given_gold > $prob_silver, "$prob_silver_given_gold > $prob_silver"); 
    
    # log (P('silver'|'gold') / P('silver')) == PMI(gold, silver)
    # so cross check condprob with PMI. 
    my $other_way_PMI = log10($prob_silver_given_gold / $prob_silver); 
    my $the_PMI = wordPMI("gold", "silver"); 
    ok ($the_PMI - $other_way_PMI < 0.01, "$the_PMI - $other_way_PMI < 0.01"); 

    # very high tested. what about very low?
    my $very_low = word_condprob("horse", "computer"); 
    ok ($very_low < 0.1, "$very_low < 0.01"); 

    # OOV 
    my $OOV_given = word_condprob("dog", "taegil"); 
    ok ($OOV_given == 0, "$OOV_given == 0"); 
    my $OOV_prob = word_condprob("taegil", "dog"); 
    ok ($OOV_prob == 0, "$OOV_prob == 0");   
}
