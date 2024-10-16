import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log(deployer);

  const marketplace = await deploy("Marketplace", {
    from: deployer,
    log: true,
  });

  console.log("Marketplace contract:", marketplace.address);

  const rentableNft = await deploy("RentableNft", {
    from: deployer,
    args: [marketplace.address],
    log: true,
  });

  console.log("RentableNft contract", rentableNft.address);
};

export default func;
func.id = "deploy_marketplace_and_nft";
func.tags = ["nft", "RentableNft"];
