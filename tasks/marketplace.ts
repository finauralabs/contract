import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const getSigner = async (hre: HardhatRuntimeEnvironment) => {
  const [signer] = await hre.ethers.getSigners();
  return signer;
};

task("marketplace:listNFT", "List NFT for rent")
  .addParam("nftContract", "The address of the NFT contract")
  .addParam("tokenId", "The ID of the NFT to list")
  .addParam("pricePerDay", "The rental price per day in wei")
  .addParam("price", "The buyout price in wei")
  .addParam("startDate", "The start date of the rental period in UNIX timestamp")
  .addParam("endDate", "The end date of the rental period in UNIX timestamp")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const signer = await getSigner(hre);
    const { deployments, ethers } = hre;
    const Marketplace = await deployments.get("Marketplace");

    const marketplace = await ethers.getContractAt("Marketplace", Marketplace.address);
    const nftContract = await ethers.getContractAt("RentableNft", taskArgs.nftContract);
    await nftContract.connect(signer).approve(await marketplace.getAddress(), taskArgs.tokenId);

    const listingFee = await marketplace.getListingFee();

    const tx = await marketplace
      .connect(signer)
      .listNFT(
        taskArgs.nftContract,
        taskArgs.tokenId,
        taskArgs.pricePerDay,
        taskArgs.price,
        taskArgs.startDate,
        taskArgs.endDate,
        { value: listingFee },
      );
    await tx.wait();
    console.log("NFT listed successfully");
  });

task("marketplace:rentNFT", "Rent an NFT")
  .addParam("nftContract", "The address of the NFT contract")
  .addParam("tokenId", "The ID of the NFT to rent")
  .addParam("expires", "The expiration date of the rental in UNIX timestamp")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { deployments } = hre;
    const Marketplace = await deployments.get("Marketplace");

    const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
    const tx = await marketplace.rentNFT(taskArgs.nftContract, taskArgs.tokenId, taskArgs.expires, {
      value: 0.1,
    });
    await tx.wait();
    console.log("NFT rented successfully");
  });

task("marketplace:unlistNFT", "Unlist an NFT")
  .addParam("nftContract", "The address of the NFT contract")
  .addParam("tokenId", "The ID of the NFT to unlist")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { deployments } = hre;
    const Marketplace = await deployments.get("Marketplace");

    const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
    const tx = await marketplace.unlistNFT(taskArgs.nftContract, taskArgs.tokenId, { value: 0.1 });
    await tx.wait();
    console.log("NFT unlisted successfully");
  });

task("marketplace:buyNFT", "Buy an NFT")
  .addParam("nftContract", "The address of the NFT contract")
  .addParam("tokenId", "The ID of the NFT to buy")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { deployments } = hre;
    const Marketplace = await deployments.get("Marketplace");

    const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
    const tx = await marketplace.buyNFT(taskArgs.nftContract, taskArgs.tokenId, { value: 0.1 });
    await tx.wait();
    console.log("NFT purchased successfully");
  });

task("marketplace:getAllListings", "Get all listings").setAction(async (_, hre: HardhatRuntimeEnvironment) => {
  const { deployments } = hre;
  const Marketplace = await deployments.get("Marketplace");

  const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
  const listings = await marketplace.getAllListings();
  console.log(listings);
});

task("marketplace:getListingFee", "Get the listing fee").setAction(async (_, hre: HardhatRuntimeEnvironment) => {
  const { deployments } = hre;
  const Marketplace = await deployments.get("Marketplace");

  const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
  const listingFee = await marketplace.getListingFee();
  console.log(listingFee.toString());
});

task("marketplace:offerBid", "Bid an NFT")
  .addParam("nftContract", "The address of the NFT contract")
  .addParam("tokenId", "The ID of the NFT to rent")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { deployments } = hre;
    const Marketplace = await deployments.get("Marketplace");

    const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
    const tx = await marketplace.offerBid(taskArgs.nftContract, taskArgs.tokenId, {
      value: hre.ethers.parseEther("0.2"),
    });
    await tx.wait();
    console.log("NFT bid successfully");
  });

task("marketplace:makeDeal", "make deal for bids")
  .addParam("nftContract", "The address of the NFT contract")
  .addParam("tokenId", "The ID of the NFT to rent")
  .addParam("buyer", "The address of the NFT buyer")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { deployments } = hre;
    const Marketplace = await deployments.get("Marketplace");

    const marketplace = await hre.ethers.getContractAt("Marketplace", Marketplace.address);
    const tx = await marketplace.makeDeal(taskArgs.nftContract, taskArgs.tokenId, taskArgs.buyer);
    await tx.wait();
    console.log("Make deal for bid successfully");
  });
