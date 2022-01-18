clc
clear all
% === Model the DL-SCH transport channel
% https://www.mathworks.com/help/5g/gs/ldpc-processing-chain-for-dl-sch.html

% === Initialization
trBlckLen = 10000; % Transport block length
crcInfoDisp(trBlckLen)

% Rate of the DL-SCH Channel
k = 449;
n = 1024;
R = k/n;
outlen = ceil(trBlckLen/R); % Length of the output of the DL-SCH block

% SNR
SNRdB = 10;
rv = 0; % Redundancy version, 0-3

% Modulation
modulation = 'QPSK';
M = 4;
nLayers = 1;

% DL-SCH coding parameters
cbsInfo = nrDLSCHInfo(trBlckLen,R);
cbSegmenDisp(trBlckLen, cbsInfo)
LDPCDisp(cbsInfo)


% --- Source
% Random transport block data generation
data = randi([0 1], trBlckLen ,1,'int8');

% =============================== DL-SCH =============================== %

% --- Transmitter
    % Add CRC bits, Transport Layer
    dataCRC = nrCRCEncode(data,cbsInfo.CRC);

    % Code block segmentation and CRC attachment, Divide the message into
    % sub-blocks and add CRC and -1 to each block such that the length of the
    % sub-block is equal to the length of th LDPC encoder
    cbsIn = nrCodeBlockSegmentLDPC(dataCRC,cbsInfo.BGN);

    % Channel Coding: LDPC encoding
    cword = nrLDPCEncode(cbsIn,cbsInfo.BGN);

    % Rate matching and code block concatenation
    channelIn = nrRateMatchLDPC(cword,outlen,rv,modulation,nLayers);
    
    % Modulation
    symbols  = qammod(channelIn, M,'InputType','bit');
    
% --- Channel
    channelOut = awgn(symbols,SNRdB,'measured');
    
% --- Receiver
    % Demodulation, and convert to doubles, in order to pass channelInHat
    % to the next block
    channelInHat = double(1-2*qamdemod(channelOut, M,'OutputType','bit'));
    
    % Rate recovery
    % nrRateRecoverLDPC is the inverse of nrRateMatchLDPC 
    % Performs the inverse of 
    % the code block concatenation, bit interleaving, and bit selection
    % stages at the receiver end.
    raterec = nrRateRecoverLDPC(channelInHat,trBlckLen,R,rv,modulation,nLayers);
    
    % LDPC decoding
    decBits = nrLDPCDecode(raterec,cbsInfo.BGN,25);
    
    % Code block desegmentation and CRC decoding
    [blk,~] = nrCodeBlockDesegmentLDPC(decBits,cbsInfo.BGN,trBlckLen+cbsInfo.L);
    
    
    % Transport block CRC decoding
    [out,tbErr] = nrCRCDecode(blk,cbsInfo.CRC);

    disp(['Transport block CRC error: ' num2str(tbErr)])
    disp(['Recovered transport block with no error: ' num2str(isequal(out,data))])

    



function crcInfoDisp(trBlckLen)

    disp('=========================== Step 1 ===========================')
    disp('============= Add CRC Bits to Transport Block ================')

    if trBlckLen <=3824
       disp('Since the Transport Block Size is less or equal to 3824, we add 16 CRC bits')
       crc = 16;
    else
        disp('Since the Transport Block Size is larger than 3824, we add 24 CRC bits')
        crc = 24;
    end
    X = ['The total length of the output of the CRC block is ',num2str(crc + trBlckLen)];
    disp(X);
    disp(' ')
end


function cbSegmenDisp(trBlckLen,cbsInfo)

    disp('=========================== Step 2 ===========================')
    disp('============= Code Block Segmentation and CRC ================')
    
    disp('There are two base graphs for LDPC coding')
    disp('In this step, we break the input into pieces with the same length')
    disp('in order to match the input of the length of the LDPC encoder')
    
    
    if trBlckLen + cbsInfo.L <= 3840
       disp('Since the size of the input to this block is less or equal to 3840, base graph 1 is selected.')
    else
        disp('Since the size of the input to this block is larger than 3840, base graph 2 is selected')
    end
    disp(' ')
end

function LDPCDisp(cbsInfo)

    disp('=========================== Step 3 ===========================')
    disp('======================= LDPC Encoding ========================')
    X =['The rate of the code is ', num2str(cbsInfo.K/cbsInfo.N)];
    disp(X)
    disp(' ')

end
