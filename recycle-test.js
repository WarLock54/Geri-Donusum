const { expect}=require("chai");
const {ethers}=require("hardhat");
const provdider=ethers.provider;
function Donusturucu(val){
    return Number(ethers.utils.formatEther(val));
}
describe("Recycle Coin",function(){
    let owner,user1,user2;
    let Token,token;
    let Recycle,recycle;
var balances;
                before(async function(){
                    [owner,user1,user2]=await ethers.getSigners();
    Token=await ethers.getContractFactory("Recycle");
    token=await Token.connect(owner).deploy();
    Recycle =await ethers.getContractFactory("Kasa");
    recycle=await Recycle.connect(owner).deploy(token.address);

    token.connect(owner).transfer(user1.address,ethers.utils.parseEther("100"));
    token.connect(owner).transfer(user2.address,ethers.utils.parseEther("50"));
    token.connect(user1).approve(recycle.address,ethers.constants.MaxInt256);
    token.connect(user2).approve(recycle.address,ethers.constants.MaxInt256);
                });

                beforeEach(async function(){
                    balances=[
                        Donusturucu(await token.balanceOf(owner.address)),
                        Donusturucu(await token.balanceOf(user1.address)),
                        Donusturucu(await token.balanceOf(user2.address)),
                        Donusturucu(await token.balanceOf(recycle.address)),
                    ]
                 });
                
                 it("Kontratlar olusuyor mu?",async function(){
                    expect(token.address).to.not.be.undefined;
                    expect(recycle.address).to.be.properAddress;
                 });
                 it(" recylce coin  gonderildi",async function(){
                    expect(balances[1].to.be.equal(100));
                    expect(balances[2].to.be.equal(50));
                    expect(balances[0].to.be.greaterThan(balances[1]))
                 });
                 
                
})