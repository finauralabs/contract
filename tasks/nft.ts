import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("mint", "Mint a new Rentable NFT")
  .addParam("uri", "The URI of the NFT metadata")
  .addParam("address", "The address mint to")
  .addParam("tokenId", "The NFT tokenId")
  .setAction(async ({ uri, address, tokenId }, hre: HardhatRuntimeEnvironment) => {
    const [deployer] = await hre.ethers.getSigners();

    const { deployments, ethers } = hre;
    const RentableNft = await deployments.get("RentableNft");

    const rentableNft = await ethers.getContractAt("RentableNft", RentableNft.address);
    const tx = await rentableNft.safeMint(address, uri, tokenId);
    await tx.wait();
    console.log(`Rentable NFT minted by ${deployer.address} with URI: ${uri}`);
  });

task("burn", "Burn a Rentable NFT")
  .addParam("tokenId", "The ID of the NFT to burn")
  .setAction(async ({ tokenId }, hre: HardhatRuntimeEnvironment) => {
    const { deployments, ethers } = hre;
    const RentableNft = await deployments.get("RentableNft");

    const rentableNft = await ethers.getContractAt("RentableNft", RentableNft.address);
    const tx = await rentableNft.burn(tokenId);
    await tx.wait();
    console.log(`Rentable NFT with ID ${tokenId} burned.`);
  });

task("tokenId", "get nft by tokenId")
  .addParam("tokenId", "The ID of the NFT to burn")
  .setAction(async ({ tokenId }, hre: HardhatRuntimeEnvironment) => {
    const { deployments, ethers } = hre;
    const RentableNft = await deployments.get("RentableNft");

    const rentableNft = await ethers.getContractAt("RentableNft", RentableNft.address);
    const uri = await rentableNft.tokenURI(tokenId);
    console.log(`tokenURI ${uri}`);
    console.log(`owner ${await rentableNft.ownerOf(tokenId)}`);
  });
