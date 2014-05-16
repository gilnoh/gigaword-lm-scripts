Conditioned Language Model experimental system. 

=== 
Please see the following document to run the minimal experiments. 
* How to make models & run minimal P(text | context)
  see making_models.txt 

=== 

List of access scripts 

* Main modules 
- condprob.pm: big, bloated and ugly main module 
- octave_call.pm: some utility codes related to sum log
probabilities. (it no longer calls octave for underlying log prob 
calculation. historical reason) 
- srilm_call.pm: some utility codes that interface with SRILM 


* Experiment runners 
- msrpc_runner.pl 
- msrpc_baseline_runner.pl 
- rte3_runner.pl 
- rte3_baseline_runner.pl 
(The above runners outputs probabilities and measures to STDOUT in CSV
format; you can load them into Weka, etc)    


* Some tools. 
- eval/simple_eval_msr_pp.pl 
- eval/simple_eval_rte3.pl 
( "threadhold" based accuracy (prec & recall also) showing scripts) 


* Model building scripts 
(see making_models.txt, for detailed steps to build models) 




