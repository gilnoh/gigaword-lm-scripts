# a runner script for MSR paraphrase corpus runner
# 

use warnings;
use strict;
#use POSIX qw(_exit);
use Benchmark qw(:all);
use condprob qw(:DEFAULT set_num_thread $DEBUG export_hash_to_file $SOLR_URL mean_allword_pmi product_best_word_condprob mean_best_wordPMI $USE_CACHE_ON_SPLITTA); 

# PARAMETERS to set (for proto_condprob.pm) 
our $DEBUG=0; # well, turn it on for quality check. 
#set_num_thread(4);
our $SOLR_URL = "http://localhost:9911/solr";
#our $APPROXIMATE_WITH_TOP_N_HITS=4000;
our $USE_CACHE_ON_SPLITTA = 1; 

# local parameter
#my $lambda = 0.2;
$| = 1; #flush always 

# usage check 
die "Usage: needs three arguments.\n\">perl runner.pl msr_filename start_num end_num \"\n perl runner.pl ./testdata/msr_paraphrase_test.txt 1 1725\n" unless ($ARGV[2]);

my $inputfile = $ARGV[0]; 

# read data 
my ($gold_aref, $t_aref, $h_aref) = MSRPC_reader($inputfile); 

my $datasize = scalar (@{$gold_aref}); 

my $START_ID = $ARGV[1] + 0;
my $END_ID = $ARGV[2] + 0;
my $RUN_ID = $ARGV[3]; 

die "start id out of bounds" if ($START_ID < 1 or $START_ID > $datasize);
die "end id out of bounds" if ($END_ID < 1 or $END_ID > $datasize);
die "end id must be bigger than start" if ($END_ID < $START_ID);


## print CSV header 
print "id, gold, meanPMI, prod bestCondProb, mean bestPMI, wgt-mean bestPMI,"; 
print "\n"; 
## 

# now select one
for (my $pair_id = $START_ID; $pair_id <= $END_ID; $pair_id++)
{
    my $id = $pair_id - 1; # id actually is starting from 0.

    my $text = call_splitta($t_aref->[$id]);
    my $hypo = call_splitta($h_aref->[$id]);

    print STDERR "Processing id $pair_id;\n";
    warn "SPLITTA failed! ==> fallback to lc(string).\n" unless($text and $hypo); 
    $text = lc($t_aref->[$id]) unless($text); 
    $hypo = lc($h_aref->[$id]) unless($hypo); 

    # patch for bad input "[" or "]". (e.g. 90th instance of test) 
    $text =~ s/\[|\]//g; 
    $hypo =~ s/\[|\]//g; 

    print STDERR "text: $text\n"; 
    print STDERR "hypo: $hypo\n"; 

    my $meanPMI = mean_allword_pmi($text, $hypo); 
    my $word_logprob1 = product_best_word_condprob($text, $hypo); 
    my $word_logprob2 = product_best_word_condprob($hypo, $text); # both direction
    my $word_logprob = ($word_logprob1 + $word_logprob2) / 2; 
    my ($mean_best_PMI_1, $weighted_mean_best_PMI_1) = mean_best_wordPMI($text, $hypo); 
    my ($mean_best_PMI_2, $weighted_mean_best_PMI_2) = mean_best_wordPMI($hypo, $text); 
    my $mean_best_PMI = ($mean_best_PMI_1 + $mean_best_PMI_2) / 2; 
    my $weighted_mean_best_PMI = ($weighted_mean_best_PMI_1 + $weighted_mean_best_PMI_2) / 2; 



    # all prepared. print 
    print "$pair_id, $gold_aref->[$id], $meanPMI, $word_logprob, $mean_best_PMI, $weighted_mean_best_PMI, "; 
    print "\n"; 

}

sub MSRPC_reader
{
    # skip the first line 
    my $file = $_[0]; 
    open FILE, "<", $file or die "unable to read $file"; 
    my $line = <FILE>; 
    

    my @gold; 
    my @first_sent; 
    my @second_sent; 

    while($line = <FILE>)
    {
         #print $line; 
         my @items = split /\t/, $line; 
         my ($g, $sent1, $sent2); 
         foreach (@items)
         {
             #print "$_\n"; 
             $g = $items[0]; 
             $sent1 = $items[3]; 
             $sent2 = $items[4]; 
         }
         #print $gold, "\t", $first_sent, "\t", $second_sent, "\n"; 
         push @gold, $g; 
         push @first_sent, $sent1; 
         push @second_sent, $sent2;          
    }
    die "Eh, need to be called within an array context" unless defined wantarray; 
    return (\@gold, \@first_sent, \@second_sent); 
}
