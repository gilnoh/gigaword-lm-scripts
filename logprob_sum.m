function logprob = logprob_sum(a, b, base=10)
% A simple function that adds two log probability. 
% (assuming and using log10) 

% log(exp(a) + exp(b)) = log(exp(a - m) + exp(b - m)) + m
% where m=max(a,b) 

m = max(a, b); 
if (base == 10)
   logprob = log10( 10^(a - m) + 10^(b - m) ) + m;
end

if (base == e)
   logprob = log(exp(a - m) + exp(b - m)) + m;
end

if (base == 2)
   logprob = log2(2^(a-m) + 2^(b-m)) + m; 
end

end 
