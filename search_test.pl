use strict; 
use warnings; 
use proto_condprob qw(:DEFAULT plucene_query); 

## if there is "AND", it breaks everything. remove "AND" from query text. 

# - why the following two returns different results? 
# "a bus collision with a truck in uganda has resulted in at least 30 fatalities and has left a further 21 injured" (small) 
# "30 die in a bus collision in uganda" (big) 
# - write a simple script and test: "bus" "bus collision" "bus collision in uganda"  
# - (I am expecting all OR relation. is it something not?) 

#my $query = "a bus collision with a truck in uganda has resulted in at least 30 fatalities and has left a further 21 injured"; 
my $query = "a bus collision with a truck in uganda has resulted in at least 30 fatalities and has"; 
my ($doc_aref, $score_href, $total_doc) = plucene_query($query); 

my $size = scalar @{$doc_aref}; 
print "$size returned\n"; 

for (my $i=0; $i < 3; $i++)
{
    my $doc = $doc_aref->[$i];
    print "$doc \t $score_href->{$doc}\n"; 
}
