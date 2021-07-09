import './App.css';
import {ethers} from 'ethers'
import Sale from './artifacts/contracts/Sale.sol/Sale.json'
import SANFT from './artifacts/contracts/SANFT.sol/SANFT.json'
import Tether from './artifacts/contracts/Tether.sol/Tether.json'
import Token from './artifacts/contracts/Token.sol/Token.json'
import deployed from './config/deployed.json'

let addresses

function App() {

  console.log("Hello World")

  // request access to the user's MetaMask account
  async function requestAccount() {
    await window.ethereum.request({method: 'eth_requestAccounts'});
  }

  async function getSigner() {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner()
    const chainId = (await provider.getNetwork()).chainId
    addresses = deployed[chainId]
    console.log(addresses)
    return signer
  }

  // call the smart contract, send an update
  async function ApproveInvestor1() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount();
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.AbcSaleAddress, Sale.abi, signer)
      const transaction = await contract.approveInvestor(addresses.investor1, 100000);
      await transaction.wait()
    }
  }

  // call the smart contract, send an update
  async function ApproveTether() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount();
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.TetherAddress, Tether.abi, signer)
      const transaction = await contract.approve(addresses.AbcSaleAddress, 2000)
      await transaction.wait()
    }
  }

  // call the smart contract, send an update
  async function InvestAbc() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.AbcSaleAddress, Sale.abi, signer)
      const transaction = await contract.invest(1000)
      await transaction.wait()
    }
  }

  async function ShowNFT() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.SANFTAddress, SANFT.abi, signer)
      let numNFT = (await contract.balanceOf(signer.getAddress())).toNumber();
      console.log("number of NFT", numNFT);
      for (let i = 0; i < numNFT; i++) {
        let nft = (await contract.tokenOfOwnerByIndex(signer.getAddress(), i)).toNumber();
        let sa = await contract.getSA(nft)
        for (let j = 0; j < sa.subSAs.length; j++) {
          console.log(sa.subSAs[j].sale);
          console.log(sa.subSAs[j].remainingAmount.toNumber());
        }
      }

      //const transaction = await contract.balanceOf(signer)
      //await transaction.wait()
    }
  }

  async function ShowABC() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.AbcAddress, Token.abi, signer)
      console.log((await contract.balanceOf(signer.getAddress())).toNumber());
    }
  }

  async function ShowTether() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.TetherAddress, Tether.abi, signer)
      console.log((await contract.balanceOf(signer.getAddress())).toNumber());
    }
  }

  async function ApproveMerge() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.TetherAddress, Tether.abi, signer)
      let transaction = await contract.approve(addresses.SANFTAddress, 100);
      await transaction.wait();
    }
  }

  async function MergeNFT() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.SANFTAddress, SANFT.abi, signer)
      let numNFT = (await contract.balanceOf(signer.getAddress())).toNumber();
      console.log("number of NFT", numNFT);
      let nftList = [];
      for (let i = 0; i < numNFT; i++) {
        let nft = (await contract.tokenOfOwnerByIndex(signer.getAddress(), i)).toNumber();
        nftList.push(nft)
      }
      console.log(nftList);
      let transaction = await contract.merge(nftList);
      await transaction.wait()
      //const transaction = await contract.balanceOf(signer)
      //await transaction.wait()
    }
  }

  async function VestNFT() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.SANFTAddress, SANFT.abi, signer)
      let numNFT = (await contract.balanceOf(signer.getAddress())).toNumber();
      console.log("number of NFT", numNFT);
      let nftList = [];
      for (let i = 0; i < numNFT; i++) {
        let nft = (await contract.tokenOfOwnerByIndex(signer.getAddress(), i)).toNumber();
        contract.vest(nft);
      }
    }
  }

  async function SplitNFT() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const signer = await getSigner()
      const contract = new ethers.Contract(addresses.SANFTAddress, SANFT.abi, signer)
      let numNFT = (await contract.balanceOf(signer.getAddress())).toNumber();
      console.log("number of NFT", numNFT);
      let nftList = [];
      for (let i = 0; i < numNFT; i++) {
        let nft = (await contract.tokenOfOwnerByIndex(signer.getAddress(), i)).toNumber();
        nftList.push(nft)
      }
      await contract.merge(nftList);
      //const transaction = await contract.balanceOf(signer)
      //await transaction.wait()
    }
  }

  return (
      <div className="App">
        <header className="App-header">
          <button onClick={ApproveTether}>Approve Tether (As Investor1)</button>
          <button onClick={ApproveInvestor1}>Approve Investor1 Abc (As AbcOwner)</button>
          <button onClick={InvestAbc}>InvestAbc (As Investor1)</button>
          <button onClick={MergeNFT}>MergeNFT</button>
          <button onClick={ShowNFT}>ShowNFT</button>
          <button onClick={VestNFT}>VestNFT</button>
          <button onClick={ShowTether}>ShowTether</button>
          <button onClick={ShowABC}>ShowABC</button>
          <button onClick={ApproveMerge}>ApproveMerge</button>
        </header>
      </div>
  );
}

export default App;