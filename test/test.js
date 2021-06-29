const hre = require("hardhat");
const {loadFixture} = require('ethereum-waffle');
const {expect} = require('chai');

const ethers = hre.ethers;

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
const dai = ethers.utils.parseUnits("10000", 18);


describe('RedAavelopes', function () {
    async function fixture([wallet, other], provider) {
        const [owner, addr1, addr2] = await ethers.getSigners();

        const RedAavelopes = await ethers.getContractFactory('RedAavelopes');
        const nftContract = await RedAavelopes.deploy();
        await nftContract.deployed();

        const aDaiContract = new ethers.Contract("0x028171bCA77440897B824Ca71D1c56caC55b68A3", erc20abi, ethers.provider);
        const daiContract = new ethers.Contract(daiAddress, erc20abi, ethers.provider);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0xDFd5293D8e347dFe59E90eFd55b2956a1343963d"]}
        )

        const signer = await ethers.provider.getSigner("0xDFd5293D8e347dFe59E90eFd55b2956a1343963d");

        await daiContract.connect(signer).transfer(owner.address, dai);

        await hre.network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: ["0xDFd5293D8e347dFe59E90eFd55b2956a1343963d"]}
        )

        expect(await daiContract.balanceOf(owner.address)).to.equal(dai);

        return {nftContract, daiContract, aDaiContract};
    }
    it('All the tests', async function () {
        const [owner, addr1, addr2] = await ethers.getSigners();

        const {nftContract, daiContract, aDaiContract} = await loadFixture(fixture);

        expect(nftContract).to.not.be.equal(null);

        const daiAmount = ethers.utils.parseUnits("1000", 18);

        await daiContract.connect(owner).approve(nftContract.address, daiAmount);
        await nftContract.mintWithDai(daiAmount, Math.floor(new Date().getTime() / 1000) + 14778800);

        expect(await nftContract.ownerOf(0)).to.be.equal(owner.address);

        // Check aDai is correct
        expect(await daiContract.balanceOf(nftContract.address)).to.be.equal(0);
        expect(await daiContract.balanceOf(owner.address)).to.be.equal(dai.sub(daiAmount));
        expect(await aDaiContract.balanceOf(nftContract.address)).to.be.equal(daiAmount);

        // Make time pass hah
        await hre.network.provider.send("evm_increaseTime", [15778800]);
        await hre.network.provider.send("evm_mine");

        // console.log(await nftContract.getSvg(0));

        // Burn
        await nftContract.burn(0);
        expect(await daiContract.balanceOf(nftContract.address)).to.be.equal(0);
        expect(await daiContract.balanceOf(owner.address)).to.be.equal(dai.add(ethers.utils.parseUnits("10", 18))); // original + 10 for interest yay!
    });

});
