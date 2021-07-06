async function main() {
    // We get the contract to deploy
    const Contract = await ethers.getContractFactory("RedAavelopes");
    const instance = await Contract.deploy();

    console.log("Deployed to:", instance.address);

    return instance
}

const erc20abi = [
    // Some details about the token
    "function name() view returns (string)",
    "function symbol() view returns (string)",

    // Get the account balance
    "function balanceOf(address) view returns (uint)",

    // Send some of your tokens to someone else
    "function transfer(address to, uint amount)",

    "function approve(address usr, uint wad) external returns (bool)",

    // An event triggered whenever anyone transfers to someone else
    "event Transfer(address indexed from, address indexed to, uint amount)"
];
const daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

async function mint(nftInstance) {
    const [owner] = await ethers.getSigners();

    const daiAmount = ethers.utils.parseUnits("1000", 18);
    const daiContract = new ethers.Contract(daiAddress, erc20abi, ethers.provider);

    // Get some DAI from Binance
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0xDFd5293D8e347dFe59E90eFd55b2956a1343963d"]}
    )

    const signer = await ethers.provider.getSigner("0xDFd5293D8e347dFe59E90eFd55b2956a1343963d");

    await daiContract.connect(signer).transfer(owner.address, daiAmount);

    await hre.network.provider.request({
        method: "hardhat_stopImpersonatingAccount",
        params: ["0xDFd5293D8e347dFe59E90eFd55b2956a1343963d"]}
    )

    console.log("DAI amount: " + await daiContract.balanceOf(owner.address));

    // mint it
    await daiContract.connect(owner).approve(nftInstance.address, daiAmount);
    await nftInstance.mintWithDai(daiAmount, Math.floor(new Date().getTime() / 1000) + 315576000);

    console.log("Owner of 0: " + await nftInstance.ownerOf(0));

    await hre.network.provider.send("evm_increaseTime", [63115200]); // 2 years pass
    await hre.network.provider.send("evm_mine");

    console.log("Advanced by two years...")

    return nftInstance
}

main().then(mint)
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
