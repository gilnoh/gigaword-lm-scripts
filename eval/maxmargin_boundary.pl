# this small script draws some box plot, 
# shows the best performance point from the (dev) data, 
# and gives us the max-margin decision boundary on the gain value. 
use warnings; 
use strict; 

# arg check 
die "Sorry; need one run result file name\n" unless ($ARGV[0]); 
die "Sorry; need the unit name: one of bb, pmi, hgt, minus\n" unless ($ARGV[1]); 
# first, sort gain values according to true (gold) answers
open FILE, "<", $ARGV[0] or die "unable to open the file\n"; 

$ARGV[2] = "non" unless $ARGV[2]; 

my @ent_gains; 
my @nont_gains; 

while (<FILE>)
{
    if (/:ENTAILMENT/)
    {
	$_=~/.+?,(.+?),(.+?),(.+?),(.+?),/; 
	push @ent_gains, $1 if ($ARGV[1] eq "bb"); 
	push @ent_gains, $2 if ($ARGV[1] eq "pmi"); 
	push @ent_gains, $3 if ($ARGV[1] eq "hgt"); 
	push @ent_gains, $4 if ($ARGV[1] eq "minus"); 
	
    }
    elsif (/:NONENTAILMENT/)
    {
	$_=~/.+?,(.+?),(.+?),(.+?),(.+?),/; 
	push @nont_gains, $1 if ($ARGV[1] eq "bb"); 
	push @nont_gains, $2 if ($ARGV[1] eq "pmi"); 
	push @nont_gains, $3 if ($ARGV[1] eq "hgt"); 
	push @nont_gains, $4 if ($ARGV[1] eq "minus"); 
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

unless ($ARGV[1] =~ /minus|bb/)
{
    `GNUTERM=X11 octave --eval "pkg load statistics; a = [$line1]; b= [$line2]; boxplot({a, b}); pause();"`; 
}
else
{
    `GNUTERM=X11 octave --eval "pkg load statistics; a = [$line1]; b= [$line2]; boxplot({log(a), log(b)}); pause();"`; 
}

my $ent_sum = 0; 
my $nont_sum = 0; 

unless ($ARGV[2]=~/log/)
{
    $ent_sum += $_ foreach (@ent_gains); 
    $nont_sum += $_ foreach (@nont_gains); 
}
else
{
    $ent_sum += log(($_ + 0.0)) foreach (@ent_gains); 
    $nont_sum += log(($_ + 0.0)) foreach (@nont_gains); 
}

my $ent_mean = $ent_sum / scalar(@ent_gains); 
my $nont_mean = $nont_sum / scalar(@nont_gains); 

if ($ARGV[2] =~ /log/)
{
    print "(log) mean of entailment gold answer : $ent_mean\n"; 
    print "(log) mean of nonentailment gold answer : $nont_mean\n"; 
}
else
{
   print "mean of entailment gold answer : $ent_mean\n"; 
   print "mean of nonentailment gold answer : $nont_mean\n"; 
}


# Eh, max margin not really needed... just mid point for now. 
my $mid = $ent_mean - (($ent_mean - $nont_mean) / 2); 
print "mid point: ", $mid, "\n"; 

if ($ARGV[2] =~ /log/)
{
    print "which is: ", exp($mid), "\n"; 
}


# calculate maxmargin decision boundaary by using data poitns between two means
# my @support_points_ent; 
# my @support_points_nont; 

# foreach (@ent_gains)
# {
#     push @support_points_ent, log($_) if ((log($_)) < $ent_mean); 
# }

# foreach (@nont_gains)
# {
#     push @support_points_nont, log($_) if ((log($_)) > $nont_mean); 
# }

