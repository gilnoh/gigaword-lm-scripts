# a perl module to call and read SRILM 
# outputs (especially those debug outputs, too) 

require Exporter;
@ISA = qw(Exporter); 
@EXPORT = qw(call_ngram read_debug3_log read_debug3_p); 

my $NGRAM_EXECUTABLE = "ngram"; 
my $NGRAM_DEBUGOPTION = "-debug 3"; # a must for us 
my $NGRAM_INPUT_FILE = "./output/ngram_input.txt"; # we use a fixed name. can't run multiple instances. 

sub call_ngram {
    # call ngram with some options. 
    # arguments are call_ngram(model_path, sentence, optional_arguments); 
    # the STDOUT of ngram, will be returned as @result 

# format 
# ngram -ppl target.txt -lm modelfile (-order or any similar options) -debug 3 
# a complex exmaple 
# ngram -ppl test.txt -lm ./afp_eng_2009/AFP_ENG_20090531.0484.story.model -mix-lm collection.model -debug 3 -bayes 0 -lambda 0.5 

# outputs come to STDOUT. so capture it. 

    my $model_path = $_[0]; 
    my $sentence_string = $_[1]; 
    my $additional_options = $_[2]; 

    # sanity check 
    die unless (defined $sentence_string); 
    die unless (-e $model_path); 
    $additional_options = "" unless (defined $additional_options); 

    # generate input file 
    open FILE, ">", "./output/ngram_input.txt"; 
    print FILE $sentence_string; 
    close FILE; 

    # make command 
    my $command = $NGRAM_EXECUTABLE . " " . "-ppl " . $NGRAM_INPUT_FILE . " " . "-lm " . $model_path . " " . $NGRAM_DEBUGOPTION . " " . $additional_options; 

    # call 
    #print STDERR $command; 
    my @result = `$command 2> /dev/null`; 
    #print @result; 

}

sub read_debug3_p {
    # return probability value itself (non-log) 
    my @result; 
    @pline = read_debug3(@_);
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
    @pline = read_debug3(@_); 
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
