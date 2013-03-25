#/usr/bin/perl 

# This small script will generate Plucene index for all 
# .story files in (direct) subdirs of /models/document 
# The generated index will be reside (on /models_index dir)

# What it does is similar to perstory_runner.pl;  
# perstory_runner runs SRILM to generate ngram model per 
# news article. This script runs internally Plucene and 
# make Plucene index. 

# get path 
die "Usage: At least one argument needed; a dir path.\n(e.g. perl indexing.pl \"./models/document\"). \nThis small script will generate Plucene index for all .story files in (direct) subdirs of /models/document\n" unless ($ARGV[0]); 



