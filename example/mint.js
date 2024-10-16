const Web3 = require("web3");
const fs = require("fs");
const path = require("path");
const { create } = require("ipfs-http-client");
const { NFTStorage, File } = require("nft.storage");

// 连接到以太坊网络
const web3 = new Web3(Web3.givenProvider || "http://localhost:8545");

// NFT合约地址和ABI
const nftContractAddress = "0x..."; // 替换为你的NFT合约地址
const nftContractABI = [
  // ... 这里需要填入你的NFT合约ABI
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "string",
        name: "tokenURI",
        type: "string",
      },
    ],
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

// 创建合约实例
const nftContract = new web3.eth.Contract(nftContractABI, nftContractAddress);

// NFT.Storage API key
const NFT_STORAGE_API_KEY = "your_nft_storage_api_key";
const nftStorage = new NFTStorage({ token: NFT_STORAGE_API_KEY });

async function createMetadata(name, description, imagePath) {
  // 读取图片文件
  const image = await fs.promises.readFile(imagePath);

  // 创建符合OpenSea标准的metadata
  const metadata = {
    name: name,
    description: description,
    image: new File([image], path.basename(imagePath), { type: "image/png" }),
    attributes: [
      {
        trait_type: "Artist",
        value: "Your Artist Name",
      },
      {
        trait_type: "Year",
        value: new Date().getFullYear().toString(),
      },
      // 可以添加更多属性
    ],
  };

  return metadata;
}

async function uploadToIPFS(metadata) {
  try {
    // 上传到IPFS
    const result = await nftStorage.store(metadata);
    console.log("Metadata uploaded to IPFS:", result.url);
    return result.url;
  } catch (error) {
    console.error("Error uploading to IPFS:", error);
    throw error;
  }
}

async function mintNFT(toAddress, tokenURI) {
  try {
    // 获取当前用户地址
    const accounts = await web3.eth.getAccounts();
    const fromAddress = accounts[0];

    console.log(`Minting NFT from ${fromAddress} to ${toAddress}`);

    // 调用合约的mint函数
    const tx = await nftContract.methods.mint(toAddress, tokenURI).send({
      from: fromAddress,
      gas: 3000000, // 设置适当的gas限制
    });

    console.log("NFT minted successfully!");
    console.log("Transaction hash:", tx.transactionHash);
    console.log("Gas used:", tx.gasUsed);

    return tx;
  } catch (error) {
    console.error("Error minting NFT:", error);
    throw error;
  }
}

async function main() {
  const recipientAddress = "0x..."; // 替换为接收NFT的地址
  const nftName = "My Awesome NFT";
  const nftDescription = "This is a unique and awesome NFT!";
  const imagePath = path.join(__dirname, "nft_image.png"); // 替换为你的NFT图片路径

  try {
    // 创建metadata
    const metadata = await createMetadata(nftName, nftDescription, imagePath);

    // 上传metadata到IPFS
    const tokenURI = await uploadToIPFS(metadata);

    // 铸造NFT
    await mintNFT(recipientAddress, tokenURI);
  } catch (error) {
    console.error("Main function error:", error);
  }
}

// 运行主函数
main();
