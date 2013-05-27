use strict;
use warnings; 

die "usage: need two args (boundary, unit name) \n" unless ($ARGV[1]); 

# get input from stdout 

my $boundary = $ARGV[0]; 
my $unit = $ARGV[1]; 

my $ent_correct=0; 
my $ent_wrong=0;
my $nont_correct=0; 
my $nont_wrong=0; 
my $total_gold_ent = 0; 
my $total_gold_nonent = 0; 
my $total_ent_predict = 0; 
my $total_nont_predict = 0; 
    
while(<STDIN>)
{
    # ger numbers 
    # TODO: fetch all numbers. 
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
	die "arg2 should be one of, 'bb', 'pmi', 'hgt', 'minus'\n"; 
    }
    
    print $gold, "\t", $target, "\t"; 

    $target = $target + 0.0; 
    $boundary = $boundary + 0.0; 

    if ($gold =~ /GOLD:ENTAILMENT\|/)
    { # TRUE is entailment ... 
        $total_gold_ent++; 
	if ($target > $boundary)
	{   
            $total_ent_predict++; 
	    $ent_correct++; 
	    print "CORRECT (Predict: ENT)\n"; 
	}
	else 
	{
            $total_nont_predict++;
	    $ent_wrong++; 
	    print "WRONG (Predict: NONENT)\n"; 
	}	
    }
    elsif($gold =~ /GOLD:NONENTAILMENT\|/)
    { # TRUE is non entailment 
        $total_gold_nonent++; 
	if ($target > $boundary)
	{
            $total_ent_predict++;
	    $nont_wrong++; 
	    print "WRONG (Predict: ENT)\n"; 
	}
	else
	{
            $total_nont_predict++;
	    $nont_correct++; 
	    print "CORRECT (Predict: NONENT)\n"; 
	}
    }    
}

# my $ent_correct=0; 
# my $ent_wrong=0;
# my $nont_correct=0; 
# my $nont_wrong=0; 

my $up = 0.0; 
$up = $up + $ent_correct + $nont_correct; 
my $denom = 0.0 + $ent_correct + $nont_correct + $ent_wrong + $nont_wrong; 
    my $accuracy = $up / $denom; 
print "correct: ", $ent_correct + $nont_correct, "\n"; 
print "wrong: ", $ent_wrong + $nont_wrong, "\n"; 
print "total accuracy: $accuracy\n"; 
print "precision on ENT: ", ($ent_correct / $total_ent_predict), "\n"; 
print "recall on ENT: ", ($ent_correct / $total_gold_ent), "\n"; 
print "precision on NONENT: ", ($nont_correct / $total_nont_predict), "\n"; 
print "recall on NONENT: ", ($nont_correct / $total_gold_nonent), "\n"; 
 

