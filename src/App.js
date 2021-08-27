import './App.css';
import { ethers } from 'ethers'
import Sale from './artifacts/contracts/Sale.sol/Sale.json'
import SANFT from './artifacts/contracts/SANFT.sol/SANFT.json'
import Tether from './artifacts/contracts/Tether.sol/Tether.json'
import Token from './artifacts/contracts/Token.sol/Token.json'

// Update with the contract address logged out to the CLI when it was deployed
const AbcAddress = "0x0AC29c9BaAdCED4D83Ef41dB3C8Ba5078c9423b2";
const XyzAddress = "0x76ba0191d98Ad83B9d8d3B672ae5fA94B94A45fD";
const AbcSaleAddress = "0x613066DC905078806cD4B613A03DaF6B04B95ef0";
const XyzSaleAddress = "0x8019EB8aBB9dD8CB194b8b2aABa52e89E3f64B14";
const TetherAddress = "0x3aA890FB22A409E500aacEb91202480673142F48";
const SANFTAddress = "0x68c3Ccc0ebbe4b5388b5328b41c04b7455298D63";
const investor1 = "0xb8736B73854a646C883De2B5a5dF6999d4b9C1A1";

function App() {

  console.log("Hello World")
  // request access to the user's MetaMask account
  async function requestAccount() {
    await window.ethereum.request({ method: 'eth_requestAccounts' });
  }

  // call the smart contract, send an update
  async function ApproveInvestor1() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount();
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(AbcSaleAddress, Sale.abi, signer)
      const transaction = await contract.approveInvestor(investor1, 100000);
      await transaction.wait()
    }
  }

  // call the smart contract, send an update
  async function ApproveTether() {
      if (typeof window.ethereum !== 'undefined') {
      await requestAccount();
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(TetherAddress, Tether.abi, signer)
      const transaction = await contract.approve(AbcSaleAddress, 2000)
      await transaction.wait()
    }
  }

  // call the smart contract, send an update
  async function InvestAbc() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(AbcSaleAddress, Sale.abi, signer)
      const transaction = await contract.invest(1000)
      await transaction.wait()
    }
  }

  async function ShowNFT() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(SANFTAddress, SANFT.abi, signer)
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
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(AbcAddress, Token.abi, signer)
      console.log((await contract.balanceOf(signer.getAddress())).toNumber());
    }
  }

  async function ShowTether() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(TetherAddress, Tether.abi, signer)
      console.log((await contract.balanceOf(signer.getAddress())).toNumber());
    }
  }

  async function ApproveMerge() {
      if (typeof window.ethereum !== 'undefined') {
        await requestAccount()
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const signer = provider.getSigner()
        const contract = new ethers.Contract(TetherAddress, Tether.abi, signer)
        let transaction = await contract.approve(SANFTAddress, 100);
        await transaction.wait();
      }
  }

  async function MergeNFT() {
    if (typeof window.ethereum !== 'undefined') {
      await requestAccount()
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(SANFTAddress, SANFT.abi, signer)
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
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(SANFTAddress, SANFT.abi, signer)
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
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner()
      const contract = new ethers.Contract(SANFTAddress, SANFT.abi, signer)
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
        <button onClick={InvestAbc}>InvestAbc (As Investor1) </button>
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