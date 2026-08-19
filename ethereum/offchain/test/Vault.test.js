import { expect } from "chai";
import { network } from "hardhat";

const { ethers, networkHelpers } = await network.getOrCreate();
const { loadFixture } = networkHelpers;

describe("Vault — los mismos casos, desde el off-chain", function () {
  async function desplegar() {
    const [alice, bob] = await ethers.getSigners();
    const vault = await ethers.deployContract("Vault");
    return { vault, alice, bob };
  }

  it("deposit acredita el saldo del que deposita", async () => {
    const { vault, alice } = await loadFixture(desplegar);
    await vault.connect(alice).deposit({ value: ethers.parseEther("1") });
    expect(await vault.balanceOf(alice.address)).to.equal(ethers.parseEther("1"));
  });

  it("los depositos sucesivos se acumulan", async () => {
    const { vault, alice } = await loadFixture(desplegar);
    await vault.connect(alice).deposit({ value: ethers.parseEther("1") });
    await vault.connect(alice).deposit({ value: ethers.parseEther("0.5") });
    expect(await vault.balanceOf(alice.address)).to.equal(ethers.parseEther("1.5"));
  });

  it("deposit emite Deposit con los datos correctos", async () => {
    const { vault, alice } = await loadFixture(desplegar);
    await expect(vault.connect(alice).deposit({ value: ethers.parseEther("1") }))
      .to.emit(vault, "Deposit").withArgs(alice.address, ethers.parseEther("1"));
  });

  it("withdraw descuenta el saldo y manda el ETH", async () => {
    const { vault, alice } = await loadFixture(desplegar);
    await vault.connect(alice).deposit({ value: ethers.parseEther("3") });
    await vault.connect(alice).withdraw(ethers.parseEther("1"));
    expect(await vault.balanceOf(alice.address)).to.equal(ethers.parseEther("2"));
  });

  it("withdraw de mas revierte con InsufficientBalance", async () => {
    const { vault, alice } = await loadFixture(desplegar);
    await vault.connect(alice).deposit({ value: ethers.parseEther("1") });
    await expect(vault.connect(alice).withdraw(ethers.parseEther("2")))
      .to.be.revertedWithCustomError(vault, "InsufficientBalance");
  });

  it("los saldos estan aislados entre usuarios", async () => {
    const { vault, alice, bob } = await loadFixture(desplegar);
    await vault.connect(alice).deposit({ value: ethers.parseEther("2") });
    await vault.connect(bob).deposit({ value: ethers.parseEther("5") });
    expect(await vault.balanceOf(alice.address)).to.equal(ethers.parseEther("2"));
    expect(await vault.balanceOf(bob.address)).to.equal(ethers.parseEther("5"));
  });
});
