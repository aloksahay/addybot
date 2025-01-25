const hre = require("hardhat");

async function main() {
  const NFT = await hre.ethers.getContractFactory("AddyNFTContract");
  
  console.log("Deploying contract...");
  const nft = await NFT.deploy(
    "Addy NFT Collection",
    "ADDY"
  );

  await nft.waitForDeployment();
  const address = await nft.getAddress();
  console.log("AddyNFTContract deployed to:", address);

  console.log("Waiting for block confirmations...");
  await nft.deploymentTransaction().wait(5);

  console.log("Verifying contract...");
  await hre.run("verify:verify", {
    address: address,
    constructorArguments: [
      "Addy NFT Collection",
      "ADDY"
    ],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 