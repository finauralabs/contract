const Web3 = require('web3');

// 假设你已经有了这些地址和 ABI
const web3 = new Web3(Web3.givenProvider || "http://localhost:8545");
const marketplaceAddress = "0x..."; // Marketplace 合约地址
const nftContractAddress = "0x..."; // NFT 合约地址
const nftContractABI = [...]; // NFT 合约的 ABI

async function checkAndApproveMarketplace() {
    try {
        // 获取当前用户地址
        const accounts = await web3.eth.getAccounts();
        const userAddress = accounts[0];

        // 创建 NFT 合约实例
        const nftContract = new web3.eth.Contract(nftContractABI, nftContractAddress);

        // 检查是否已授权
        const isApproved = await nftContract.methods.isApprovedForAll(userAddress, marketplaceAddress).call();

        if (!isApproved) {
            console.log("Marketplace not approved. Sending approval transaction...");

            // 发送授权交易
            const tx = await nftContract.methods.setApprovalForAll(marketplaceAddress, true).send({
                from: userAddress,
                gas: 200000 // 设置适当的 gas 限制
            });

            console.log("Approval transaction sent:", tx.transactionHash);
            console.log("Waiting for confirmation...");

            // 等待交易被确认
            const receipt = await web3.eth.getTransactionReceipt(tx.transactionHash);
            if (receipt.status) {
                console.log("Approval successful!");
            } else {
                console.log("Approval failed.");
            }
        } else {
            console.log("Marketplace already approved.");
        }
    } catch (error) {
        console.error("An error occurred:", error);
    }
}

// 调用函数
checkAndApproveMarketplace();