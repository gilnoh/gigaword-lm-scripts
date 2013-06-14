# simple script that will list one value per column, 
# from the given CSV file. 

# CSV file should be given to STDIN (redirection) 
use warnings; 
#use strict; 

my @marker; 
my @bb;
my @pmi; 
my @value_itself; 
my @diff; 

my @len_t; 
my @len_h; 
my @h_t; 
my @t; 
my @h; 

while (<STDIN>)
{
    my $line = $_; 
    $line =~ /^(.+?),(.+?),(.+?),(.+?),(.+?),(.+?),(.+?),(.+?),(.+?),(.+?),/; 

    my $marker = $1; 
    push @bb, $2;
    push @pmi, $3; 
    push @value_itself, $4; 
    push @diff, $5; 
    push @len_t, $6; 
    push @len_h, $7; 
    push @h_t, $8; 
    push @t, $9; 
    push @h, $10; 

    if ($marker =~ /NONENTAILMENT/)
    {
	push @marker, -1; 
    }
    else
    {
	push @marker, 1; 
    }
}


for (my $i=0; $i < scalar(@marker); $i ++)
{
    print "$marker[$i] 1:$bb[$i] 2:$pmi[$i] 3:$value_itself[$i] 4:$diff[$i] 5:$len_t[$i] 6:$len_h[$i] 7:$h_t[$i] 8:$t[$i] 9:$h[$i]\n";
#    print "$marker[$i] 1:$bb[$i] 2:$pmi[$i] 3:$value_itself[$i] 4:$diff[$i]\n";
#    print "$marker[$i] 1:$pmi[$i]\n"; 
#    print "$marker[$i] 1:$diff[$i]\n"; 
}
exit(0);
 # Don't use the following, but use svm scale 


#=== 
# now we have all of them. normalize them. 

my @norm_bb = normalize(@bb); 
my @norm_pmi = normalize(@pmi); 
my @norm_value_itself = normalize(@value_itself); 
my @norm_diff = normalize(@diff); 

for (my $i=0; $i < scalar(@marker); $i ++)
{
    print "$marker[$i] $norm_bb[$i], $norm_pmi[$i], $norm_value_itself[$i], $norm_diff[$i]\n"; 
}

# output 
sub normalize
{
    # get mean 
    my @values = @_; 
    my $count = scalar(@values); 

    my $sum = 0; 
    foreach my $v (@values)
    {
	$sum += $v; 
    }
    
    my $mean = $sum / $count; 

    # get standard deviation 
    my @diffsum = 0; 
    foreach my $v (@values)
    {
	$diffsum += (($mean - $v) ** 2); 
    }
    my $std = sqrt ( $diffsum / $count ); 
    print STDERR "mean: $mean, std: $std\n"; 

    # normalize. 
    my @result = (); 
    for(my $i=0; $i < scalar(@values); $i++)
    {
	$result[$i] = (($values[$i] - $mean) / $std); 
    }
    return @result; 
}
