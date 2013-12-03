# a perl module to call and read SRILM 
# outputs (especially those debug outputs, too) 

package srilm_call; 

use strict; 
use warnings; 
use Exporter;

our @ISA = qw(Exporter); 
our @EXPORT = qw(set_ngram_input_file read_debug3_p call_ngram); 

our $NGRAM_EXECUTABLE = "ngram"; 
our $NGRAM_DEBUGOPTION = "-debug 3"; # a must for us 
our $NGRAM_INPUT_FILE = "./models/ngram_input.txt"; ## we use a fixed name. ## careful not to change the file, when running multiple threads. 


sub set_ngram_input_file($)
{
    # if multiple sentences are called simiultanously, this must 
    # be set accordingly. (multiple instances ...) 
    # note that this file is all shared by collection model call and 
    # document model calls (threds, etc) 
    $NGRAM_INPUT_FILE = $_[0]; 
}


sub call_ngram($;$$) {
    # call ngram with some options. 
    # arguments are call_ngram(model_path, optional_arguments*, sentence**); 
    # only first argument is mandatory. 
    # * if missing, no optional arguments will be given. 
    # ** if missing, will run on previously called text. 
    # the STDOUT of ngram, will be returned as @result 
    
    # call would be made like this; 
    # ngram -ppl in.txt -lm modelfile (-order or any similar options) -debug 3 

    my $model_path = $_[0]; 
    my $additional_options = $_[1]; 
    my $sentence_string = $_[2]; 

    # sanity check 
    die unless (-e $model_path); 
    $additional_options = "" unless (defined $additional_options); 
    
    # generate input file, if $sentence_string is given 
    if (defined $sentence_string)
    {
	open FILE, ">", $NGRAM_INPUT_FILE; 
	print FILE $sentence_string; 
	close FILE;
    }

    die "Something wrong. This is a new call without sentence, or file write failed\n" unless (-r $NGRAM_INPUT_FILE); 

    # make command 
    my $command = $NGRAM_EXECUTABLE . " " . "-ppl " . $NGRAM_INPUT_FILE . " " . "-lm " . $model_path . " " . $NGRAM_DEBUGOPTION . " " . $additional_options; 

    # call 
    #print STDERR $command; 
    my @result = `$command 2> /dev/null`; 
    #my @result = `$command`; 

    # sanity check 
    die "\n ngram call fails, or problematic - no stdout from SRILM ngram. Check that commandline program ngram is in path \n" unless (@result); 
    return @result; 
}

sub read_debug3_p {
    # return probability value itself (non-log) 
    my @result; 
    my @pline = read_debug3(@_);
    foreach (@pline)
    {
	/.\] (.+?) \[ /; 
	push @result, $1; 
    }
    return @result; 
}

sub read_debug3_log {
    # return log probability part of each word 
    my @result; 
    my @pline = read_debug3(@_); 
    foreach (@pline)
    {
	/ \[ (.+?) \] \/ 1/; 
	push @result, $1 
    }
    return @result; 
}

sub read_debug3 {
    # print STDERR @lines; 
    # all ngram -ppl [input] -debug 3 outputs will be passed 
    # to this method. 
    # first line, original sentence 
    # then each line, "\t" p (something) 
    # finally, some closeing things 
    # let's pick all lines with \t, since we are assuming single sentence  
    my @lines = @_; 
    my @result; 
    foreach (@lines)
    {
	push @result, $_ if (/^\t/); 
    }
    return @result; 

}

1; 
