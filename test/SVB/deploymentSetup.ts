/* global describe it before ethers */

import { getSelectors, FacetCutAction, removeSelectors, findAddressPositionInFacets } from "../../scripts/libraries/diamond"
import { deployDiamond } from "../../scripts/deploy"
import { assert } from "chai"
import { ethers } from "hardhat"
import { Contract } from "ethers"

import { time, loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs"
import { expect } from "chai"

describe("InitializationTest", async function () {
    let diamondAddress: string
    let diamondCutFacet: Contract
    let diamondLoupeFacet: Contract
    let ownershipFacet: Contract
    let mintingBullsFacet: Contract
    let saltRepositoryFacet: Contract
    let infoGetterFacet: Contract
    let adminSetterFacet: Contract
    let saltVaultToken: Contract
    let mockedUSDC: Contract

    let signers: any
    let owner: any
    let coreTeamWallet: any
    let royaltiesWallet: any
    let procurementWallet: any
    let vaultWallet1: any
    let vaultWallet2: any
    let vaultWallet3: any
    let badActorWallet: any
    let mockedExchange: any

    let tx
    let receipt
    let result
    const addresses: string[] = []

    before(async function () {
        // Deploy Diamond and Get Facet Information
        diamondAddress = await deployDiamond()
        console.log({ diamondAddress })
        diamondCutFacet = await ethers.getContractAt("DiamondCutFacet", diamondAddress)
        diamondLoupeFacet = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress)
        ownershipFacet = await ethers.getContractAt("OwnershipFacet", diamondAddress)
        mintingBullsFacet = await ethers.getContractAt("MintingBullsFacet", diamondAddress)
        saltRepositoryFacet = await ethers.getContractAt("SaltRepositoryFacet", diamondAddress)
        infoGetterFacet = await ethers.getContractAt("InfoGetterFacet", diamondAddress)
        adminSetterFacet = await ethers.getContractAt("AdminSetterFacet", diamondAddress)

        // await initializeDataFacet.connect(owner).initEcosystemData()

        // Deploy MockedUSDC and disperse these tokens

        // Get a list of available signers
        signers = await ethers.getSigners()

        owner = signers[0]
        coreTeamWallet = signers[1]
        royaltiesWallet = signers[2]
        procurementWallet = signers[3]
        vaultWallet1 = signers[4]
        vaultWallet2 = signers[5]
        vaultWallet3 = signers[6]
        mockedExchange = signers[30]
        badActorWallet = signers[13]

        // MockedUSDC
        const MockedUSDC = await ethers.getContractFactory("MockedUSDC", mockedExchange)
        mockedUSDC = await MockedUSDC.deploy(100000000 * 10 ** 6)
        await mockedUSDC.waitForDeployment()

        // Transfer tokens from signers[30] to signers[1] through signers[17]
        const amount = ethers.parseUnits("10000", 6) // Assuming MockedUSDC uses 6 decimal places

        for (let i = 10; i <= 20; i++) {
            await mockedUSDC.connect(mockedExchange).transfer(signers[i].address, amount)
        }

        // Salt Vault Token
        const SaltVaultToken = await ethers.getContractFactory("SaltVaultToken")
        saltVaultToken = await SaltVaultToken.deploy()
        await saltVaultToken.waitForDeployment()
    })

    it("should have 7 facets -- call to facetAddresses function", async () => {
        for (const address of await diamondLoupeFacet.facetAddresses()) {
            addresses.push(address)
        }
        console.log({ addresses })
        assert.equal(addresses.length, 7)
    })

    describe("Starting Bull Variables", function () {
        it("Confirm Diamond Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(0)

            expect(Number(bullData[0])).to.equal(0) // Rarity
            expect(Number(bullData[1])).to.equal(2500 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(300) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(1) // currentIndex
            expect(Number(bullData[4])).to.equal(50) // lastIndex
        })

        it("Confirm Ruby Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(1)

            expect(Number(bullData[0])).to.equal(1) // Rarity
            expect(Number(bullData[1])).to.equal(1000 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(200) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(51) // currentIndex
            expect(Number(bullData[4])).to.equal(500) // lastIndex
        })

        it("Confirm Platinum Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(2)

            expect(Number(bullData[0])).to.equal(2) // Rarity
            expect(Number(bullData[1])).to.equal(750 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(175) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(501) // currentIndex
            expect(Number(bullData[4])).to.equal(2000) // lastIndex
        })

        it("Confirm Gold Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(3)

            expect(Number(bullData[0])).to.equal(3) // Rarity
            expect(Number(bullData[1])).to.equal(500 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(150) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(2001) // currentIndex
            expect(Number(bullData[4])).to.equal(4000) // lastIndex
        })

        it("Confirm Silver Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(4)

            expect(Number(bullData[0])).to.equal(4) // Rarity
            expect(Number(bullData[1])).to.equal(350 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(130) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(4001) // currentIndex
            expect(Number(bullData[4])).to.equal(6000) // lastIndex
        })

        it("Confirm Bronze Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(5)

            expect(Number(bullData[0])).to.equal(5) // Rarity
            expect(Number(bullData[1])).to.equal(200 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(115) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(6001) // currentIndex
            expect(Number(bullData[4])).to.equal(8000) // lastIndex
        })

        it("Confirm Blank Bull Information", async function () {
            let bullData = await infoGetterFacet.getBullRarityInformation(6)

            expect(Number(bullData[0])).to.equal(6) // Rarity
            expect(Number(bullData[1])).to.equal(100 * 10 ** 6) // mintCost
            expect(Number(bullData[2])).to.equal(100) // rewardMultiplier
            expect(Number(bullData[3])).to.equal(8001) // currentIndex
            expect(Number(bullData[4])).to.equal(10000) // lastIndex
        })
    })

    describe("Starting Salt Repository Variables", function () {
        it("Confirm Salt Grain Prices", async function () {
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(1, 0, 0, 0)).to.equal(1 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(10, 0, 0, 0)).to.equal(10 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(18, 0, 0, 0)).to.equal(18 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(0, 1, 0, 0)).to.equal(9 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(0, 7, 0, 0)).to.equal(7 * 9 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(0, 27, 0, 0)).to.equal(27 * 9 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(0, 0, 1, 0)).to.equal(85 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(0, 0, 0, 1)).to.equal(800 * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(1, 1, 1, 1)).to.equal((800 + 85 + 9 + 1) * 10 ** 6)
            expect(await saltRepositoryFacet.getSaltGrainPurchasePrice(0, 5, 5, 8)).to.equal((800 * 8 + 85 * 5 + 9 * 5) * 10 ** 6)
        })
    })

    describe("Starting Salt Repository Variables", function () {
        it("assert USDC has been sent by mockedExchange", async () => {
            expect(await mockedUSDC.balanceOf(signers[5])).to.equal(0)
            expect(await mockedUSDC.balanceOf(signers[10])).to.equal(10_000 * 10 ** 6)
        })

        it("set Minting Bulls to Live when not ready", async () => {
            await expect(adminSetterFacet.connect(owner).setMintStatus(true)).to.be.revertedWith("Addresses must be set first")
        })

        it("set Addresses on Contract", async () => {
            await adminSetterFacet.connect(owner).setAddresses(mockedUSDC.getAddress(), saltVaultToken.getAddress(), coreTeamWallet.address, royaltiesWallet.address, procurementWallet.address)

            expect(await infoGetterFacet.getUsdcContractAddress()).to.equal(mockedUSDC.target)
            expect(await infoGetterFacet.getSaltVaultTokenAddress()).to.equal(saltVaultToken.target)
            expect(await infoGetterFacet.getCoreTeamWalletAddress()).to.equal(coreTeamWallet.address)
            expect(await infoGetterFacet.getRoyaltiesWalletAddress()).to.equal(royaltiesWallet.address)
            expect(await infoGetterFacet.getProcurementWalletAddress()).to.equal(procurementWallet.address)
        })

        it("set Minting Bulls to Live", async () => {
            await adminSetterFacet.connect(owner).setMintStatus(true)

            expect(await infoGetterFacet.getMintStatus()).to.equal(true)
        })

        // it("Let person10 mint a Diamond Bull NFT", async function () {
        //     const expectedAddressToMintTo = signers[10].address
        //     const expectedTokenId = 1
        //     const expectedMintCost = 2500 * 10 ** 6
        //     const expectedAum = 2500 * 0.9 * 10 ** 6
        //     const expectedGrains = 0
        //     const expectedPillars = 0
        //     const expectedSheets = 5
        //     const expectedCubes = 2
        //     const expectedBonusGrains = 250

        //     // Amount to approve (make sure this is sufficient for the mint operation)
        //     const amountToApprove = await infoGetterFacet.getCostAndMintEligibility(0)

        //     expect(amountToApprove).to.equal(expectedMintCost)

        //     console.log("usdcContract:", await infoGetterFacet.getUsdcContractAddress())

        //     // Approve the proxySVB contract to spend tokens
        //     await mockedUSDC.connect(signers[10]).approve(mintingBullsFacet, amountToApprove)

        //     await mintingBullsFacet.connect(signers[10]).mintBull(0, signers[10].address, 1)

        //     // // Now attempt the mint
        //     // await expect(mintingBullsFacet.connect(signers[10]).mintBull(0, signers[10].address, 1)).to.emit(mintingBullsFacet.target, "MintedBull").withArgs(expectedAddressToMintTo, expectedTokenId, expectedMintCost, expectedAum, expectedGrains, expectedPillars, expectedSheets, expectedCubes, expectedBonusGrains)

        //     expect(await mintingBullsFacet.totalSupply()).to.equal(1)

        //     let bull = await infoGetterFacet.getBullInformation(1)
        //     console.log("bull:", bull)

        //     console.log("balanceOf:", await mintingBullsFacet.balanceOf(signers[10]))
        //     console.log("walletOfOwner:", await infoGetterFacet.walletOfOwner(signers[10]))
        // })

        // it("test sending ERC20 to diamond", async function () {

        // })
        const _1K = 1_000 * 10 ** 6
        it("Owner buys 10,000 $SVT for reward distribution", async function () {
            // Setup SVT token now that proxySVB is known
            await saltVaultToken.connect(signers[0]).setSaltVaultBullsAddress(mintingBullsFacet.target)
            await saltVaultToken.connect(signers[0]).setUnderlyingToken(mockedUSDC)
            await saltVaultToken.connect(signers[0]).setFeeReceiver(signers[6].address)

            await saltVaultToken.connect(signers[0]).setCustomFee([signers[6].address, signers[10].address], [100000, 100000])

            await saltVaultToken.connect(signers[0]).activateToken(true)

            await mockedUSDC.connect(signers[10]).approve(saltVaultToken.target, _1K)
            await saltVaultToken.connect(signers[10]).mintWithBacking(_1K)
        })

        it("Assert owner has 10,000 $SVT", async function () {
            expect(await saltVaultToken.balanceOf(signers[10])).to.equal(_1K)
        })

        it("test diamond to safeTransfer mockedUSDC on the mintingFacet", async function () {
            let p10_usdc_balance_before = await mockedUSDC.balanceOf(signers[10])
            let p10_svt_balance_before = await saltVaultToken.balanceOf(signers[10])

            let facet_balance_before = await mockedUSDC.balanceOf(mintingBullsFacet.target)

            console.log("mockedUSDC balance of person10 :", Number(p10_usdc_balance_before) / 10 ** 6)
            console.log("SVT balance of person10        :", Number(p10_svt_balance_before) / 10 ** 6)
            // console.log("mockedUSDC balance of facet:", Number(facet_balance_before) / 10 ** 6)

            // // await mockedUSDC.connect(signers[10]).transfer(mintingBullsFacet.target, 10 * 10 ** 6)

            await saltVaultToken.connect(signers[10]).approve(mintingBullsFacet.target, 10 * 10 ** 6)

            await mockedUSDC.connect(signers[10]).approve(mintingBullsFacet.target, 10 * 10 ** 6)

            await mintingBullsFacet.test10(signers[10].address)

            let p10_usdc_balance_after = await mockedUSDC.balanceOf(signers[10])
            let p10_svt_balance_after = await saltVaultToken.balanceOf(signers[10])

            let facet_balance_after = await mockedUSDC.balanceOf(mintingBullsFacet.target)

            console.log("mockedUSDC balance of person10 :", Number(p10_usdc_balance_after) / 10 ** 6)
            console.log("SVT balance of person10        :", Number(p10_svt_balance_after) / 10 ** 6)

            // let p10_balance_after = await mockedUSDC.balanceOf(signers[10])
            // let facet_balance_after = await mockedUSDC.balanceOf(mintingBullsFacet.target)
            // console.log()
            // console.log("mockedUSDC balance of person10:", Number(p10_balance_after) / 10 ** 6)
            // // console.log("mockedUSDC balance of facet:", Number(facet_balance_after) / 10 ** 6)
        })
    })
})
