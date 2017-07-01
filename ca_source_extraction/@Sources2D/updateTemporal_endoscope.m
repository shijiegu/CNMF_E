function [C_offset] = updateTemporal_endoscope(obj, Y, allow_deletion)
%% run HALS by fixating all spatial components
% input:
%   Y:  d*T, fluorescence data
%   allow_deletion: boolean, allow deletion (default: true) 
% output:
%   C_raw: K*T, temporal components without being deconvolved

% Author: Pengcheng Zhou, Carnegie Mellon University, adapted from Johannes

% options
maxIter = obj.options.maxIter;
deconv_options_0 = obj.options.deconv_options;

if ~exist('allow_deletion', 'var')
    allow_deletion = true; 
end
%% initialization
A = obj.A;
K = size(A, 2);     % number of components
C = obj.C;
C_raw = zeros(size(C));
C_offset = zeros(K, 1);
S = zeros(size(C));
A = full(A);
U = A'*Y;
V = A'*A;
aa = diag(V);   % squares of l2 norm all all components
sn =  zeros(1, K);
smin = zeros(1,K);
% kernel = obj.kernel;
kernel_pars = cell(K,1);
%% updating
ind_del = false(K, 1);
for miter=1:maxIter
    for k=1:K
        if ind_del
            continue;
        end
        temp = C(k, :) + (U(k, :)-V(k, :)*C)/aa(k);
        %remove baseline and estimate noise level
        if range(temp)/std(temp)>6
            [b, tmp_sn] = estimate_baseline_noise(temp);
        else
            b = mean(temp(temp<median(temp)));
            tmp_sn = GetSn(temp);
        end
        % we use two methods for estimating the noise level
        %         psd_sn = GetSn(temp);
        %         if tmp_sn>psd_sn
        %             tmp_sn =psd_sn;
        %             [temp, ~] = remove_baseline(temp, tmp_sn);
        %         else
        %             temp = temp - b;
        %         end
        temp = temp -b;
        sn(k) = tmp_sn;
        
        % deconvolution
        if obj.options.deconv_flag
            [ck, sk, deconv_options]= deconvolveCa(temp, deconv_options_0, 'maxIter', 2);
            smin(k) = deconv_options.smin;
            kernel_pars{k} = reshape(deconv_options.pars, 1, []);
        else
            ck = max(0, temp);
        end
        % save convolution kernels and deconvolution results
        C(k, :) = ck;
        
        if sum(ck(2:end))==0
            ind_del(k) = true;
        end
        % save the spike count in the last iteration
        if miter==maxIter
            if obj.options.deconv_flag
                S(k, :) = sk;
            end
            C_raw(k, :) = temp;
        end
    end
end
obj.A = bsxfun(@times, A, sn);
obj.C = bsxfun(@times, C, 1./sn');
obj.C_raw = bsxfun(@times, C_raw, 1./sn');
obj.S = bsxfun(@times, S, 1./sn');
obj.P.kernel_pars =cell2mat( kernel_pars);
obj.P.smin = smin/sn;
obj.P.sn_neuron = sn; 
if allow_deletion
    obj.delete(ind_del);
end
