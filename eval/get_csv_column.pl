# simple script that will list one value per column, 
# from the given CSV file. 

# CSV file should be given to STDIN (redirection) 
use warnings; 
#use strict; 

die "need column number as the first arg\n" unless ($ARGV[0]); 

while (<STDIN>)
{
    $_ =~ /^(.+?),\s?(.+?),\s?(.+?),\s?(.+?),\s?(.+?),\s?(.+?),/; 
    my $colval = ${$ARGV[0]}; 
    if ($1 =~ /:ENTAILMENT/)
    {
	print "+1 "; 
    }
    else 
    {
	print "-1 "; 
    }
    print $colval, "\n"; 
}
