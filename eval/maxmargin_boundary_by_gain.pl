# this small script draws some box plot, 
# shows the best performance point from the (dev) data, 
# and gives us the max-margin decision boundary on the gain value. 
use warnings; 
use strict; 

# arg check 
die "Sorry; need one run result file name\n" unless ($ARGV[0]); 

# first, sort gain values according to true (gold) answers
open FILE, "<", $ARGV[0] or die "unable to open the file\n"; 

my @ent_gains; 
my @nont_gains; 

while (<FILE>)
{
    if (/:ENTAILMENT/)
    {
	$_=~/.+?, (.+?),/; 
	push @ent_gains, $1; 
    }
    elsif (/:NONENTAILMENT/)
    {
	$_=~/.+?, (.+?),/; 
	push @nont_gains, $1; 
    }
    else
    {
	die "something wrong: regex or file problem\n"; 
    }
}

my @sorted_ent_gains = sort {$a <=> $b} @ent_gains; 
my @sorted_nont_gains = sort {$a <=> $b} @nont_gains; 

# draw boxplot 
my $line1; 
foreach (@ent_gains)
{
    $line1 .= "$_ ,"; 
}

#`GNUTERM=X11 octave --eval "pkg load statistics; a = [$line1]; plot(log(a)); pause();"`; 

my $line2; 
foreach (@nont_gains)
{
    $line2 .= "$_ ,"; 
}

`GNUTERM=X11 octave --eval "pkg load statistics; a = [$line1]; b= [$line2]; boxplot({a, b}); pause();"`; 

`GNUTERM=X11 octave --eval "pkg load statistics; a = [$line1]; b= [$line2]; boxplot({log(a), log(b)}); pause();"`; 

# the plots clearly shows that mean and variance are only meaningful in "log" space. 

# calc log means

my $ent_sum = 0; 
my $nont_sum = 0; 
$ent_sum += log($_) foreach (@ent_gains); 
$nont_sum += log($_) foreach (@nont_gains); 

my $ent_mean = $ent_sum / scalar(@ent_gains); 
my $nont_mean = $nont_sum / scalar(@nont_gains); 

print "(log) mean of entailment gold answer P(h|t)/P(h) gains: $ent_mean\n"; 
print "(log) mean of nonentailment gold answer P(h|t)/P(h) gains: $nont_mean\n"; 
# calculate maxmargin decision boundaary by using data poitns between two means
my @support_points_ent; 
my @support_points_nont; 

foreach (@ent_gains)
{
    push @support_points_ent, log($_) if ((log($_)) < $ent_mean); 
}

foreach (@nont_gains)
{
    push @support_points_nont, log($_) if ((log($_)) > $nont_mean); 
}

# Eh, max margin not really needed... just mid point for now. 
my $mid = $ent_mean - (($ent_mean - $nont_mean) / 2); 
print "mid point: ", $mid, "\n"; 
print "which is: ", exp($mid), "\n"; 

