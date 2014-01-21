
# this small script observe values reported by 
# CLM P( h | t ), PMI ( P(h|t) / P(h)), MINUS (ppl_uncond - ppl_h_given_t) , 
# and "absolute PPL" of P(h|t). 

use warnings; 
use strict; 

die "usage: > perl observe_value.pl csv_filename column_number\n" unless ($ARGV[1]); 

my @csvdata; # arr of arr

read_format($ARGV[0]); 

my $observe_target = $ARGV[1] if ($ARGV[1]); 
my $arg_val = $ARGV[2] if ($ARGV[2]); 

observe($observe_target);
exit(); 

# observe($index) -- observes $csvdata[each]->[$index]
# reports mean, media, ENTAILMENT mean/median, NONENTAILMENT mean/median
# also accuracy at mean/median point
sub observe
{

    my $index = $_[0]; 
    print "Observing values on index $index\n"; 

    # collect all values as one list 
    my @list; 
    my @entlist; 
    my @nonentlist; 

    foreach my $aref (@csvdata)
    {
        my $val = $aref->[$index]; 
        push @list, $val; 
        if ($aref->[0] eq "ENTAILMENT")
        {
            push @entlist, $val; 
        }
        elsif ($aref->[0] eq "NONENTAILMENT")
        {
            push @nonentlist, $val; 
        }
        else
        {
            die "integraty failure (should not see this error)\n"; 
        }
    }
    my $mean = mean(@list); 
    my $ent_mean = mean(@entlist); 
    my $nonent_mean = mean (@nonentlist); 
    print "mean: $mean, "; 
    print "entailment mean: $ent_mean, "; 
    print "nonentailment mean: $nonent_mean\n"; 

    my $median = median(@list); 
    my $ent_median = median(@entlist); 
    my $nonent_median = median(@nonentlist); 
    print "median: $median, "; 
    print "entailment median: $ent_median, "; 
    print "nonentailment median: $nonent_median\n"; 

    my $result_mean = accuracy_at_boundary($index, $mean); 
    print "Accuracy with boundary at mean: $result_mean\n";
    my $result_ent_mean = accuracy_at_boundary($index, $ent_mean); 
    print "Accuracy with boundary at ent_mean: $result_ent_mean\n";
    my $result_nonent_mean = accuracy_at_boundary($index, $nonent_mean); 
    print "Accuracy with boundary at nonent_mean: $result_nonent_mean\n";
    my $result_median = accuracy_at_boundary($index, $median);  
    print "Accuracy with boundary at median: $result_median\n"; 

    if ($arg_val)
    {
        my $result_argval = accuracy_at_boundary($index, $arg_val); 
        print "Accuracy with boundary at $arg_val: $result_argval\n"; 
    }

}

# arg (index, boundary)
#
sub accuracy_at_boundary
{
    my $index = $_[0]; 
    my $boundary = $_[1]; 

    my @list; 
    my @gold; 
    foreach my $aref (@csvdata)
    {
        my $val = $aref->[$index]; 
        push @list, $val; 
        push @gold, $aref->[0]; 
    }

    my $count_corr=0;
    my $count_incorr=0; 
    my $count_gold_ent = 0; 
    my $count_gold_nonent = 0; 
    my $count_ent_predict = 0; 
    my $count_nonent_predict = 0; 
    my $count_ent_correct = 0; 
    my $count_ent_wrong = 0; 
    my $count_nonent_correct = 0; 
    my $count_nonent_wrong = 0; 

    for(my $i=0; $i < scalar(@list); $i++)
    {
        my $val = $list[$i]; 
        my $estimation; 

        if ($val > $boundary)
        {
            $estimation = "ENTAILMENT"; 
            $count_ent_predict++; 
        }
        else
        {
            $estimation = "NONENTAILMENT"; 
            $count_nonent_predict++; 
        }

        $count_gold_ent++ if ($gold[$i] eq "ENTAILMENT"); 
        $count_gold_nonent++ if ($gold[$i] eq "NONENTAILMENT"); 

        if ($gold[$i] eq $estimation)
        {
            $count_corr++; 
            if ($estimation eq "ENTAILMENT")
            {
                $count_ent_correct++;
            }
            else
            {
                $count_nonent_correct++; 
            }
        }
        else
        {
            $count_incorr++;
            if ($estimation eq "ENTAILMENT")
            {
                $count_ent_wrong++; 
            }
            else
            {
                $count_nonent_wrong++; 
            }
        }
    }    
    # prec/recall
    print "EntPrec: ", ($count_ent_correct / $count_ent_predict), "\t"; 
    print "EntRecall: ", ($count_ent_correct / $count_gold_ent), "\n"; 
    print "NonEntPrec: ", ($count_nonent_correct / $count_nonent_predict), "\t"; 
    print "NonEntRec: ", ($count_nonent_correct / $count_gold_nonent), "\n"; 

    # corr / all predic
    print "($count_corr, $count_incorr, ", scalar(@list), ")\t"; 
    
    my $result = $count_corr / ($count_corr + $count_incorr); 
    return $result; 
}


sub median
{
    my @input = sort {$b <=> $a} @_; 
    
    # dcode
    # foreach (@input) 
    # {
    #     print $_, ", "; 
    # }
    my $size = scalar(@input); 
    my $ind = $size / 2; 
    return $input[$ind]; 
}

sub mean
{
    my @input = @_; 
    my $size = scalar(@input); 
    my $sum = 0.0; 
    foreach my $v (@input)
    {
        $sum += ($v + 0.0); 
    }
    return ( $sum / $size); 
}


sub read_format
{
    my $filename = $_[0]; 
    
    # read file and make anon-array for each line, 
    # put it in global @csvdata 
    open FILEIN, "<", $filename; 
    while(<FILEIN>)
    {
        my @value = split /,/; 
        # value[0] = id & gold 
        # value[1] = bb_val
        # value[2] = PMI
        # value[3] = PPL (h | t) 
        # ... 

        my @r; 
        $value[0] =~ /GOLD:(.+)\|/; 
        $r[0] = $1; # gold result 

        print STDERR "$r[0],"; 
        for(my $i=1; $i < scalar(@value); $i++)
        {
            $r[$i] = $value[$i]; 
            print STDERR "$r[$i],"; 
        }

        #print STDERR "$r[0],$r[1],$r[2],$r[3],$r[4]\n"; 
        print STDERR "\n"; 
        push @csvdata, [@r]; 
    }
    close FILEIN; 
}
