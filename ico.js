var $ = jQuery;
jQuery(document).ready(function($) {
    let STATE_NAMES = ['NotInitialized', 'WaitingForDeposits', 'DepositsReceived', 'PurchaseConfirmed', 'PurchaseCancelled'];

    let web3 = null;
    let tokenContract = null;
    let crowdsaleContract = null;


    setTimeout(init, 1000);
    $('#loadContractsBtn').click(init);

    function init(){
        web3 = loadWeb3();
        if(web3 == null) return;
        //console.log("web3: ",web3);
        loadContract('./build/contracts/NigamCoin.json', function(data){
            tokenContract = data;
            $('#tokenABI').text(JSON.stringify(data.abi));
        });
        loadContract('./build/contracts/NigamCrowdsale.json', function(data){
            crowdsaleContract = data;
            $('#crowdsaleABI').text(JSON.stringify(data.abi));
        });
    }

    //Step 1.1
    $('#publishToken').click(function(){
        if(crowdsaleContract == null) return;
        let form = $('#publishTokenForm');

        let contractDef = tokenContract;
        let contractObj = web3.eth.contract(contractDef.abi);
        console.log('Creating contract '+contractDef.contract_name, 'ABI', JSON.stringify(contractDef.abi));
        let contractInstance = contractObj.new(
            {
                from: web3.eth.accounts[0], 
                data: contractDef.unlinked_binary,
            },
            function(error, contract){
                waitForContractCreation(error, contract, 
                    $('input[name=publishedTx]',form),
                    $('input[name=publishedAddress]',form),
                    function(contract){
                        $('input[name=publishedAddress]','#publishCrowdsaleForm').val(contract.address);
                    }
                );
            }
        );
    });
    //Step 1.2
    $('#publishCrowdsale').click(function(){
        if(crowdsaleContract == null) return;
        let form = $('#publishCrowdsaleForm');

        let tokenAddress = $('input[name=tokenAddress]', form).val();

        let contractDef = crowdsaleContract;
        let contractObj = web3.eth.contract(contractDef.abi);
        console.log('Creating contract '+contractDef.contract_name, ' with arguments:\n',
            tokenAddress,
            '\nABI', JSON.stringify(contractDef.abi));
        let contractInstance = contractObj.new(
            tokenAddress,
            {
                from: web3.eth.accounts[0], 
                data: contractDef.unlinked_binary,
            },
            function(error, contract){
                waitForContractCreation(error, contract, 
                    $('input[name=publishedTx]',form),
                    $('input[name=publishedAddress]',form),
                    function(contract){
                        //do nothing
                    }
                );
            }
        );
    });


    //====================================================

    function loadWeb3(){
        if(typeof window.web3 == "undefined"){
            printError('No MetaMask found');
            return null;
        }
        let Web3 = require('web3');
        let web3 = new Web3();
        web3.setProvider(window.web3.currentProvider);
        return web3;
    }
    function loadContract(url, callback){
        $.ajax(url,{'dataType':'json', 'cache':'false', 'data':{'t':Date.now()}}).done(callback);
    }

    function waitForContractCreation(error, contract, txField, contractField, publishedCallback){
        if(!!error) {
            console.error('Publishing failed: ', error);
            let message = error.message.substr(0,error.message.indexOf("\n"));
            printError(message);
            return;
        }
        if (typeof contract.transactionHash !== 'undefined') {
            if(typeof contract.address == 'undefined'){
                console.log('Transaction published! transactionHash: ' + contract.transactionHash);
                if(txField) txField.val(contract.transactionHash);
            }else{
                console.log('Contract mined! address: ' + contract.address + ' transactionHash: ' + contract.transactionHash);
                if(contractField) contractField.val(contract.address);
                if(typeof publishedCallback === 'function') publishedCallback(contract);
            }
        }else{
            console.error('Unknown error. Contract: ', contract);
        }             
    }




    function printError(msg){
        if(msg == null || msg == ''){
            $('#errormsg').html('');    
        }else{
            console.error(msg);
            $('#errormsg').html(msg);
        }
    }
});
