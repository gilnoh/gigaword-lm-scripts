function probsum = weighted_sum (X) 
% weighted gets an input matrix with two columns 
% column 1: document_prob 
% column 2: sequence_prob within that document.

result = 0; % careful not to pass this to logprob_sum. 

for i=X' % for each row 
    doc_log_prob = i(1);
    seq_log_prob = i(2);
    this_log_prob = doc_log_prob + seq_log_prob; 
    if (result == 0)
       result = this_log_prob; 
    else
       result = logprob_sum(result, this_log_prob); 
    endif 
   
endfor
probsum = result; 

end 

