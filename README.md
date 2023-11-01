# wrapped-mUSD


### design

this contract is a wrap token of mUSD, user can deposit(wrap) or withdraw(unwrap) mUSD to this contract to get corresponding wrapped token. And can transfer or approve this wrapped token as a normal erc-20 token.

##### deposit

when user deposit (or wrap) musd to this contract, the contract will accumulate a balance of wrapped musd at that time as well as amount of shares.

##### withdraw and transfer

unlike musd, user's balance in this wrapped musd will not rise after deposit. 

As balance of one share of mUSD may grow, when user withdraw or transfer, `share-amount` they unwrapped or transfer may be less than that as they wrapped. But corresponding balance of mUSD will remain unchanged as before.


### build

first, install dependencies

```
$ npm install
```

or 

```
$ yarn
```

and then, set your secret in `{$project_root}/.secret.js`

```
$ touch .secret.js
```

and fill `.secret.js` by following contents

```
module.exports = {
    pk: '${private_key}', // your secret key of deploy address
}
```

compile

```
$ npx hardhat compile
```


### deploy

before deploy, you should set networks's rpc in `hardhat.config.js`.

and run following command to deploy

```
$ HARDHAT_NETWORK=${network_name} node \
 scripts/wrapMUSD/deployWrapMUSDFlatten.js \
 ${token_name} \
 ${token_symbol} \
 ${musd_address} \
 ${charge_receiver}
```

`${network_name}` is name of network you want to deploy, name of network should be same as it in hardhat.config.js

`${token_name}` and `${token_symbol}` are name and symbol of this wrapped token you want.

`${musd_address}` is address of `MUSD` on that network.

`${charge_receiver}` is address who can collect charged fees.

you should fill variables in above command.
