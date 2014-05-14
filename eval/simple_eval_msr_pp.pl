#/usr/bin.perl 

use warnings; 
use strict; 

# setting 
my $gold_col = 1; 
my $measure_col = 7; 

# start

die "usage: perl simple_eval [result csv] [cut_point]\n" unless ($ARGV[1]); 
my $file_name = $ARGV[0]; 
my $cut_point = $ARGV[1]; 

open FILE, "<", $file_name; 


my $true_para = 0; 
my $true_nonpara = 0; 
my $false_para = 0; 
my $false_nonpara = 0; 
my $cases = 0; 
my $count_gold_para =0; 
my $count_gold_nonpara =0; 
while (my $line = <FILE>)
{
    my @col = split /,/, $line; 
    my $gold = $col[$gold_col]; 
    my $val = $col[$measure_col]; 

    # skip, if this is not a valid case 
    next unless ($col[0] =~ /\d/); # id must be number; if not, probably concated (two or more results file) 

    $cases ++; 
    if ($gold == 1)
    {# gold is true paraphrase
        $count_gold_para++; 
        if ($val >= $cut_point)
        {# decision was also paraphrase. (correct)
            $true_para ++; 
        }
        else
        {# decision was non-paraphrase (wrongly)
            $false_nonpara ++; 
        }
    }
    elsif ($gold == 0)
    {# gold is non paraphrase 
        $count_gold_nonpara++; 
        if ($val < $cut_point)
        {# decision was also nonparaphrase (correct)
            $true_nonpara ++; 
        }
        else
        {# decision was paraphrase (wrongly)
            $false_para ++; 
        }
    }    
    else
    {
        die "wrong gold $gold"; 
    }
}
close FILE; 


print "counted $cases cases\n"; 
print "count of gold paraphrase: $count_gold_para\n";
print "count of gold non-paraphrase; $count_gold_nonpara\n"; 
print "===\n"; 
print "true paraphrase: $true_para\n"; 
print "true non-paraphrase: $true_nonpara\n"; 
print "false paraphrase: $false_para\n"; 
print "false non-paraphrase: $false_nonpara\n"; 
my $correct = $true_para + $true_nonpara; 
my $incorrect = $false_para + $false_nonpara; 
my $acc = $correct / ($correct + $incorrect); 
my $prec = $true_para / ($true_para + $false_para); 
my $recall = $true_para / ($true_para + $false_nonpara); 
warn "something wrong, count inaccurate\n" unless (($correct + $incorrect) == $cases); 
print "accuracy: ", $correct, " / ", ($correct + $incorrect), " = $acc\n"; 
print "prec: ", $prec, "\n"; 
print "recall: ", $recall, "\n"; 


