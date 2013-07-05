use strict;
use warnings; 

die "usage: need four args (unit name, start, end, size of increment), and input from stdin \n" unless ($ARGV[3]); 

# get input from stdout 
my $unit = $ARGV[0]; 
my $start = $ARGV[1]; 
my $end = $ARGV[2]; 
my $incr = $ARGV[3]; 
    
my @result_lines; 
while(<STDIN>)
{
    push @result_lines, $_; 
}

my %acc; 
#my $point; 
for (my $point=$start; $point < $end; $point += $incr)
{   
    print STDERR "$point \t"; 
    $acc{$point} = get_accuracy(\@result_lines, $unit, $point); 
}

my @sorted_boundaries = sort ({ $acc{$a} <=> $acc{$b} } keys %acc); 

print "======\n"; 
print "sorted\n"; 
print "======\n"; 

for(@sorted_boundaries)
{
    print "$_\t accuracy at $_, with $unit: $acc{$_}\n"; 
}
 

sub get_accuracy
{
    my $ent_correct=0; 
    my $ent_wrong=0;
    my $nont_correct=0; 
    my $nont_wrong=0; 
    my $total_gold_ent = 0; 
    my $total_gold_nonent = 0; 
    my $total_ent_predict = 0; 
    my $total_nont_predict = 0; 

    my @result_lines = @{$_[0]}; 
    my $unit = $_[1]; 
    my $boundary = $_[2]; 

    # ger numbers 
    # TODO: fetch all numbers. 

    foreach(@result_lines)
    {
	$_ =~ /^(.+?),(.+?),(.+?),(.+?),(.+?),(.+?)/; 
	my $gold = $1; 
	my $bb = $2; 
	my $pmi = $3; 
	my $pw_hgt = $4; 
	my $hgt_m_h = $5; 

	my $target = "NaN";  
	# set unit. 
	$target = $bb if ($unit =~ /bb|BB/); 
	$target = $pmi if ($unit =~ /pmi|PMI/); 
	$target = $pw_hgt if ($unit =~ /hgt/); 
	$target = $hgt_m_h if ($unit =~ /minus/); 
    
	if ($target eq "NaN")
	{
	    die "arg should be one of, 'bb', 'pmi', 'hgt', 'minus'\n"; 
	}

	#print $gold, "\t", $target, "\t"; 

	#$target = $target + 0.0; 
	#$boundary = $boundary + 0.0; 

	if ($gold =~ /GOLD:ENTAILMENT\|/)
	{ # TRUE is entailment ... 
	    $total_gold_ent++; 
	    if ($target > $boundary)
	    {   
		$total_ent_predict++; 
		$ent_correct++; 
		#print "CORRECT (Predict: ENT)\n"; 
	    }
	    else 
	    {
		$total_nont_predict++;
		$ent_wrong++; 
		#print "WRONG (Predict: NONENT)\n"; 
	    }	
	}
	elsif($gold =~ /GOLD:NONENTAILMENT\|/)
	{ # TRUE is non entailment 
	    $total_gold_nonent++; 
	    if ($target > $boundary)
	    {
		$total_ent_predict++;
		$nont_wrong++; 
		#print "WRONG (Predict: ENT)\n"; 
	    }
	    else
	    {
		$total_nont_predict++;
		$nont_correct++; 
		#print "CORRECT (Predict: NONENT)\n"; 
	    }
	}    
    }

    my $up = 0.0; 
    $up = $up + $ent_correct + $nont_correct; 
    my $denom = 0.0 + $ent_correct + $nont_correct + $ent_wrong + $nont_wrong; 
    my $accuracy = $up / $denom; 
     print "accuracy at $boundary, with $unit: $accuracy\n";  

    print "correct: ", $ent_correct + $nont_correct, "\n"; 
    print "wrong: ", $ent_wrong + $nont_wrong, "\n"; 
    print "total accuracy: $accuracy\n"; 
#    print "precision on ENT: ", ($ent_correct / $total_ent_predict), "\n"; 
#    print "recall on ENT: ", ($ent_correct / $total_gold_ent), "\n"; 
#    print "precision on NONENT: ", ($nont_correct / $total_nont_predict), "\n";
#    print "recall on NONENT: ", ($nont_correct / $total_gold_nonent), "\n"; 
    return $accuracy; 
}
