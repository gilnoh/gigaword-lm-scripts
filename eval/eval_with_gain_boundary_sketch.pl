use strict;
use warnings; 


die "usage: need one arg (boundary) \n" unless ($ARGV[0]); 

# get input from stdout 

my $boundary = $ARGV[0]; 

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
    # get num
    $_ =~ /^(.+?),(.+?),/; 
    my $gold = $1; 
    my $gain = $2;
    print $gold, "\t", $gain, "\t"; 

    $gain = $gain + 0.0; 
    $boundary = $boundary + 0.0; 

    if ($gold =~ /GOLD:ENTAILMENT\|/)
    { # TRUE is entailment ... 
        $total_gold_ent++; 
	if ($gain > $boundary)
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
	if ($gain > $boundary)
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
 

