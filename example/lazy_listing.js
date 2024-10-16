const Web3 = require("web3");

// 连接到以太坊网络（这里使用Metamask提供的provider）
const web3 = new Web3(window.ethereum);

// 定义EIP-712的类型数据
const EIP712_DOMAIN = [
  { name: "name", type: "string" },
  { name: "version", type: "string" },
  { name: "chainId", type: "uint256" },
  { name: "verifyingContract", type: "address" },
];

const LAZY_LISTING_TYPE = [
  { name: "owner", type: "address" },
  { name: "nftContract", type: "address" },
  { name: "tokenId", type: "uint256" },
  { name: "pricePerDay", type: "uint256" },
  { name: "startDateUNIX", type: "uint256" },
  { name: "endDateUNIX", type: "uint256" },
  { name: "nonce", type: "uint256" },
];

async function createLazyListing(owner, nftContract, tokenId, pricePerDay, startDateUNIX, endDateUNIX) {
  // 确保用户已连接钱包
  await window.ethereum.request({ method: "eth_requestAccounts" });

  // 获取当前的nonce（这可能需要从你的后端获取）
  const nonce = await getNonceFromBackend(owner);

  // 获取当前的chainId
  const chainId = await web3.eth.getChainId();

  // 创建EIP-712结构化数据
  const domain = {
    name: "NFT Marketplace",
    version: "1",
    chainId: chainId,
    verifyingContract: "0x1234...", // 你的Marketplace合约地址
  };

  const message = {
    owner,
    nftContract,
    tokenId,
    pricePerDay,
    startDateUNIX,
    endDateUNIX,
    nonce,
  };

  const data = JSON.stringify({
    types: {
      EIP712Domain: EIP712_DOMAIN,
      LazyListing: LAZY_LISTING_TYPE,
    },
    domain: domain,
    primaryType: "LazyListing",
    message: message,
  });

  // 使用EIP-712签名
  const signature = await web3.eth.personal.sign(`0x${Buffer.from(data).toString("hex")}`, owner, "");

  // 返回签名和其他必要的信息
  return {
    ...message,
    signature,
  };
}

// 使用示例
async function exampleUsage() {
  const owner = "0x1234..."; // NFT所有者的地址
  const nftContract = "0xabcd..."; // NFT合约地址
  const tokenId = "1"; // NFT的tokenId
  const pricePerDay = web3.utils.toWei("0.1", "ether"); // 每日租金，例如0.1 ETH
  const startDateUNIX = Math.floor(Date.now() / 1000); // 当前时间
  const endDateUNIX = startDateUNIX + 30 * 24 * 60 * 60; // 30天后

  try {
    const lazyListing = await createLazyListing(owner, nftContract, tokenId, pricePerDay, startDateUNIX, endDateUNIX);
    console.log("Lazy listing created:", lazyListing);
    // 这里你可以将lazyListing发送到你的后端进行存储
  } catch (error) {
    console.error("Error creating lazy listing:", error);
  }
}

// 假设的函数，用于从后端获取nonce
async function getNonceFromBackend(owner) {
  // 这里应该是一个实际的API调用来获取下一个可用的nonce
  // 返回值应该是一个递增的数字，确保每次调用都返回一个新的nonce
  return 0; // 这只是一个占位符
}

exampleUsage();
