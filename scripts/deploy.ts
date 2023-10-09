import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  const Treasury = await ethers.getContractFactory("Treasury");
  const treasury = await Treasury.deploy(process.env.USDC_TOKEN_ADDRESS, process.env.UNISWAP_ROUTER_ADDRESS, process.env.UNISWAP_PRICE_FEED_ADDRESS, process.env.USDT_TOKEN_ADDRESS, process.env.DAI_TOKEN_ADDRESS); 

  await treasury.deployed();

  console.log("Treasury contract address:", treasury.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
