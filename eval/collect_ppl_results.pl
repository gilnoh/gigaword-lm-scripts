# this small script collect PPL running results from 
# multiple PPL output files (such as output from ppl_runner1.pl) 
use strict; 
use warnings; 

# get file names

my @files = @ARGV; 

my ($total_coll, $total_nullcontext, $total_model, $total_words, $total_sents) = (0,0,0,0,0); 

for my $f (@files)
{
    open FILE, "<", $f;
    my @lines;
    while(<FILE>)
    {
        push @lines, $_; 
    }
    close FILE;

    my ($coll, $nullcontext, $model, $words, $sents) = sum_file_summary_lines(@lines); 
    #print STDERR "$coll, $nullcontext, $model, $words, $sents\n"; 
    
    # update
    $total_coll += $coll; 
    $total_nullcontext += $nullcontext; 
    $total_model += $model; 
    $total_words += $words; 
    $total_sents += $sents; 
    
}

# finally, 
print STDERR "$total_coll, $total_nullcontext, $total_model, $total_words, $total_sents\n"; 
print "Collection model PPL: ", calc_ppl($total_coll, $total_words, $total_sents), " \n"; 
print "Model without context PPL: ", calc_ppl($total_nullcontext, $total_words, $total_sents), " \n"; 
print "Model with context PPL: ", calc_ppl($total_model, $total_words, $total_sents), " \n"; 


sub sum_file_summary_lines
{
    my @lines = @_; 
    my ($sum_coll, $sum_null, $sum_model, $sum_words, $sum_sents) = (0,0,0,0,0); 
    for (my $i=0; $i < scalar(@lines); $i++)
    {
        next unless ($lines[$i] =~ /of this doc/);

        # now we are at it. 
        my $l = $lines[$i+1]; 
        $i++; 

        # extract the info 
        my ($coll, $null, $model, $words, $sents) = split /\s+/, $l; 
        #print STDERR "$coll $null $model $words $sents\n"; 
        # update sum 
        $sum_coll += $coll; 
        $sum_null += $null; 
        $sum_model += $model; 
        $sum_words += $words; 
        $sum_sents += $sents; 
    }

    return ($sum_coll, $sum_null, $sum_model, $sum_words, $sum_sents); 
}


sub calc_ppl {
    my $logprob = shift;
    my $count_non_oov_words = shift;
    my $count_sentences = shift;
    print STDERR "($logprob, $count_non_oov_words, $count_sentences)\n";
    # ppl = 10^(-logprob/(words - OOVs + sentences))
    # ppl1 = 10^(-logprob/(words - OOVs))
    my $ppl = 10 ** (- $logprob / ($count_non_oov_words + $count_sentences));
    return $ppl;
}
