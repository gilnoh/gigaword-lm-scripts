# 2nd test codes, mostly about solr 

use strict;
use warnings; 
use octave_call; 
use srilm_call; 
use proto_condprob qw(:DEFAULT set_num_thread P_coll P_doc plucene_query solr_query get_path_from_docid $COLLECTION_MODEL $DOCUMENT_INDEX_DIR $DEBUG $APPROXIMATE_WITH_TOP_N_HITS); 
use Test::Simple tests => 5; 

our $DEBUG = 2; 
set_num_thread(2); 
our $APPROXIMATE_WITH_TOP_N_HITS=4000; 

my $text = lc "A bus collision with a truck in Uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
my $hypothesis = lc "30 dies in a bus collision in Uganda"; 

# call plucene and solr query compare the results 
my $q1_result_aref = solr_query($text); 
my $q2_result_aref = solr_query($hypothesis); 

print "q1: $text\n"; 
print "Some top doc ids for q1\n"; 
for(my $i=0; $i < 5; $i++)
{
    print $q1_result_aref->[$i], "\n"; 
}
print "Some less-well top hits (1000th) for q1\n"; 
for(my $i=1000; $i < 1005; $i++)
{
    print $q1_result_aref->[$i], "\n"; 
}

ok ((scalar @$q1_result_aref) == 4000); 

print "q2: $hypothesis\n"; 
print "Some top doc ids for q2\n"; 
for(my $i=0; $i < 5; $i++)
{
    print $q2_result_aref->[$i], "\n"; 
}
print "Some less-well top hits (1000th) for q2\n"; 
for(my $i=1000; $i < 1005; $i++)
{
    print $q2_result_aref->[$i], "\n"; 
}

ok ((scalar @$q2_result_aref) == 4000); 

my $q3 = "us prosecutor a suspect in the russia spy saga cracked after his arrest , confessing he was a russian agent and pledging greater loyalty to the kremlin than to his own son , us prosecutors said thursday ."; 

my $q3_result_aref = solr_query($q3); 
print "q3: $q3\n"; 
print "Some top doc ids for q3\n"; 
for(my $i=0; $i < 5; $i++)
{
    print $q3_result_aref->[$i], "\n"; 
}
print "Some less-well top hits (1000th) for q3\n"; 
for(my $i=1000; $i < 1005; $i++)
{
    print $q3_result_aref->[$i], "\n"; 
}
ok ((scalar @$q3_result_aref) == 4000); 

my $path1 = get_path_from_docid("AFP_ENG_20100701.0001.story"); 
my $path2 = get_path_from_docid("AFP_ENG_20100916.0268.story"); 

print $path1, "\n"; 
if (-d "./models/document/afp_eng_201007")
{
    ok (-r $path1)
}
else 
{ 
    ok (1); 
}

print $path2, "\n"; 
if (-d "./models/document/afp_eng_201009")
{
    ok (-r $path2)
}
else 
{ 
    ok (1); 
}
    

