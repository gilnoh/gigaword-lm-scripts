# this small script simply runs runner, which takes care of actual running. 
# see rte_runner for its detail (approximate N hit args, etc) 
# This script will get the output and just store them for training purpose. 

# gets no argumnet. you always have to set/change values. 

use strict; 
use warnings; 
use Benchmark qw(:all); 

my $RUNNER_SCRIPT = "rte3_runner.pl"; 
my $SIZE= 800;
my $DEF_ARGS = "test"; 

my @out; 

my $t0 = Benchmark->new; 

# simply run them and collect the output 
for (my $i=220; $i < ($SIZE + 1); $i++)
{
    print STDERR ">>>>> $i <<<<<\n"; 
    my $stdout = `perl $RUNNER_SCRIPT $i $DEF_ARGS`; 
    print $stdout; 
    push @out, $stdout; 
    print STDERR "<<<<< $i done >>>>>\n"; 
}

my $t1 = Benchmark->new; 
my $td = timediff($t1, $t0); 
print STDERR "The loop took in total:", timestr($td), "\n"; 
exit(0); 

#print "$_" foreach (@out); 
