function probsum = weighted_sum (X) 
% calculates weighted sum, 
% gets an input matrix with two columns: X
% column 1: document_prob (weight vector, per doc, weight as logprob) 
% column 2: sequence_prob (prob per doc, as logprob) 

%% POSSIBLE IMPROVEMENT? this is a "for loop" function. Can't we do this  
%% somehow in matrix operation? hmm. Not trivial, but might be possible. 

result = 0; % careful not to pass zero to logprob_sum. 
col1_sum = 0; 

for i=X' % for each row 
    doc_log_prob = i(1);
    seq_log_prob = i(2);
    this_log_prob = doc_log_prob + seq_log_prob; 
    if (result == 0)
       result = this_log_prob; 
    else
       result = logprob_sum(result, this_log_prob); 
    endif 

    if (col1_sum == 0)
       col1_sum = doc_log_prob; 
    else
      col1_sum = logprob_sum(col1_sum, doc_log_prob); 
    endif
   
endfor

% Ok, now divide it with column1 sum 
probsum = result - col1_sum; 

%probsum = result; 
end 

