
# this small script observe values reported by 
# CLM P( h | t ), PMI ( P(h|t) / P(h)), MINUS (ppl_uncond - ppl_h_given_t) , 
# and "absolute PPL" of P(h|t). 

use warnings; 
use strict; 
##
## line format is. 
#
#1|GOLD:ENTAILMENT|, bb_val(TBD), 2.99161633476937, 68.6793281132553, 147.806145602165, 5, 1, -11.0209562269589, -14.0125725617283
#
# CSV 
# column1: id & gold, 
# column2: bb value (gain) (PPL(P(h|t)) / PPL(P(t|t))) 
# column3: PMI (gain) (P(h|t) / P(h)) 
# column4: PPL of H (abs) 
# column5: MINUS (gain) (PPL_unconditioned - PPL conditioned) 
# column6: number of tokens 
# column7: number of sentences 
# column8: P(h|t) (abs)
# column9: P(h) (abs)

# TODO read and report "median" cut point, and accuracy 
#      - for PMI
#      - for PPL (abs) 
#      - for MINUS 
#      - (for BB when it comes) 

# TODO report based on "decision function" 
#      - write "decision functions" 

die unless ($ARGV[0]); 

my @csvdata; # arr of arr

read_format($ARGV[0]); 

my $arg_val = $ARGV[1] if ($ARGV[1]); 

# 1 bb
# 2 pmi (gain) 
# 3 PPL (-abs) 
# 4 MINUS (gain) 
observe(3);  # observe that index. reports 

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
    for(my $i=0; $i < scalar(@list); $i++)
    {
        my $val = $list[$i]; 
        my $estimation; 
        if ($val > $boundary)
        {
            $estimation = "ENTAILMENT"; 
        }
        else
        {
            $estimation = "NONENTAILMENT"; 
        }
        if ($gold[$i] eq $estimation)
        {
            $count_corr++; 
        }
        else
        {
            $count_incorr++;
        }
    }
    print "($count_corr, $count_incorr, ", scalar(@list), ")\n"; 
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
        # value[4] = gain PPL 
        # value[5,6] = word, sent 
        # value[7,8] = P(h|t), P(h) 

        my @r; 
        $value[0] =~ /GOLD:(.+)\|/; 
        $r[0] = $1; # gold result 
        $r[1] = $value[1]; #bb 
        $r[2] = $value[2]; #pmi 
        $r[3] = - $value[3]; #PPL (h | t) 
        $r[4] = $value[4]; #PPL gain

        print STDERR "$r[0],$r[1],$r[2],$r[3],$r[4]\n"; 
        push @csvdata, [@r]; 
    }
    close FILEIN; 
}
