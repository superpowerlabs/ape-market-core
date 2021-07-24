const hre = require("hardhat");
const { expect } = require("chai");

describe("Profile Tests", function() {
  hre.run('compile');
  it("Profile Test", async function() {
    [deployer, address1, address2, address3, address4]
        = await ethers.getSigners();

    console.log("Deploying Profile");
    Profile = await hre.ethers.getContractFactory("Profile");
    profile = await Profile.deploy()
    await profile.deployed();
    console.log("Profile deployed to:", profile.address);

    await profile.connect(address1).setAssociatedAddress(address2.address);
    expect(await profile.isMutualAssociatedAddress(address1.address, address2.address)).to.equal(false);
    await profile.connect(address2).setAssociatedAddress(address1.address);
    expect(await profile.isMutualAssociatedAddress(address1.address, address2.address)).to.equal(true);
    })
})